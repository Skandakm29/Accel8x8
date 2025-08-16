// mac_unit.v
// Low-power MAC: hierarchical enable, sparsity skip, operand isolation.
// Power-intent summary:
//  - local_en = en & row_en & col_en gates *all* sequential updates.
//  - Operand regs update only when local_en = 1  → fewer toggles.
//  - Multiplier inputs are driven to 0 when disabled (operand isolation)
//    so the multiplier tree stays quiet.
//  - If either operand is zero, we skip accumulation (sparsity).
//  - Outputs/psum HOLD when disabled → prevents downstream switching.
// Synthesis note: use "compile -gate_clock" (or equivalent) to let tools map
// these enables to ICG cells if your library has them.
//author: K M Skanda
//email:kmskanda29@gmail.com


module mac_unit #(
    parameter A_W = 8,                 // activation width (signed)
    parameter W_W = 8,                 // weight width (signed)
    parameter PSUM_W = 24              // accumulator width (signed)
)(
    input  wire                        clk,
    input  wire                        rst,          // synchronous, active-high

    // Hierarchical enables (preferred over raw clock gating in RTL)
    input  wire                        en,           // PE-level enable
    input  wire                        row_en,       // row domain enable
    input  wire                        col_en,       // column domain enable

    // Systolic dataflow: in from left/top, out to right/down
    input  wire signed [A_W-1:0]       activation_in,
    input  wire signed [W_W-1:0]       weight_in,
    output reg  signed [A_W-1:0]       activation_out,
    output reg  signed [W_W-1:0]       weight_out,

    // Partial-sum chaining (left→right)
    input  wire signed [PSUM_W-1:0]    partial_sum_in,
    output reg  signed [PSUM_W-1:0]    partial_sum_out
);

    // ----------------------------------------------------------------
    // 1) Central clock-enable: drives *all* state updates
    //    (tools can infer an ICG cell from these enables)
    // ----------------------------------------------------------------
    wire local_en = en & row_en & col_en;

    // ----------------------------------------------------------------
    // 2) Operand registers:
    //    Capture only when enabled → no internal switching while idle.
    // ----------------------------------------------------------------
    reg signed [A_W-1:0] act_reg;
    reg signed [W_W-1:0] wgt_reg;

    // ----------------------------------------------------------------
    // 3) Sparsity-aware skip:
    //    If any operand is zero, multiplication is pointless → skip add.
    //    (Comparators are cheap vs. toggling a full multiplier tree.)
    // ----------------------------------------------------------------
    wire act_zero = (act_reg == {A_W{1'b0}});
    wire wgt_zero = (wgt_reg == {W_W{1'b0}});
    wire do_mac   = local_en & ~(act_zero | wgt_zero);

    // ----------------------------------------------------------------
    // 4) Operand isolation:
    //    When disabled, drive multiplier inputs to 0 to stop glitching.
    // ----------------------------------------------------------------
    wire signed [A_W-1:0] a_iso = local_en ? act_reg : {A_W{1'b0}};
    wire signed [W_W-1:0] w_iso = local_en ? wgt_reg : {W_W{1'b0}};

    // Narrow signed multiply, then sign-extend to PSUM_W:
    // keeps the multiplier as small as possible for lower dynamic power.
    wire signed [A_W+W_W-1:0] prod_narrow = a_iso * w_iso;
    wire signed [PSUM_W-1:0]  prod_ext =
        {{(PSUM_W-(A_W+W_W)){prod_narrow[A_W+W_W-1]}}, prod_narrow};

    // ----------------------------------------------------------------
    // 5) Sequential section:
    //    - Capture operands only on enable.
    //    - Forward streams only on enable (hold when idle to avoid toggles).
    //    - Accumulate only when do_mac (enabled & non-zero operands).
    //    - HOLD state when disabled → zero switching on all FFs.
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            act_reg         <= {A_W{1'b0}};
            wgt_reg         <= {W_W{1'b0}};
            activation_out  <= {A_W{1'b0}};
            weight_out      <= {W_W{1'b0}};
            partial_sum_out <= {PSUM_W{1'b0}};
        end else begin
            // Operand capture with CE
            if (local_en) begin
                act_reg <= activation_in;
                wgt_reg <= weight_in;
            end
            // Stream forwarding: update only when enabled; otherwise HOLD.
            if (local_en) begin
                activation_out <= activation_in;
                weight_out     <= weight_in;
            end
            // Accumulate
            if (do_mac)            partial_sum_out <= partial_sum_in + prod_ext;
            else if (local_en)     partial_sum_out <= partial_sum_in; // enabled but skipped
            // else: HOLD (no update) when disabled
        end
    end

endmodule
