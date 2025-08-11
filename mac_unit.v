// author: K M Skanda
// email: kmskanda29@gmail.com
// mac_unit_lp_adv.v
// Low-power MAC with hierarchical gating, sparsity skip, and operand isolation.
// - activation_in, weight_in are signed 8-bit (quantized).
// - partial_sum is signed 24-bit (accum width).
// - local_en = en & row_en & col_en (hierarchical enable).

module mac_unit #(
    parameter A_W = 8,
    parameter W_W = 8,
    parameter PSUM_W = 24
) (
    input  wire                        clk,
    input  wire                        rst,
    // Enables
    input  wire                        en,       // per-PE enable (from scheduler / controller)
    input  wire                        row_en,   // row-level enable (hierarchical)
    input  wire                        col_en,   // column-level enable (hierarchical)
    // Data in/out (systolic dataflow)
    input  wire signed [A_W-1:0]       activation_in,
    input  wire signed [W_W-1:0]       weight_in,
    output reg  signed [A_W-1:0]       activation_out,
    output reg  signed [W_W-1:0]       weight_out,
    // Partial sum chaining
    input  wire signed [PSUM_W-1:0]    partial_sum_in,
    output reg  signed [PSUM_W-1:0]    partial_sum_out
);

    // local enable (hierarchical)
    wire local_en;
    assign local_en = en & row_en & col_en;

    // operand registers (capture operands only when local_en)
    reg signed [A_W-1:0] activation_reg;
    reg signed [W_W-1:0] weight_reg;

    // zero detection for sparsity skipping
    wire activation_is_zero = (activation_reg == {A_W{1'b0}});
    wire weight_is_zero     = (weight_reg     == {W_W{1'b0}});
    wire skip_mac           = activation_is_zero | weight_is_zero;

    // operand isolation for multiplier inputs
    // When not enabled, feed zeros to multiplier to keep the datapath quiet.
    wire signed [A_W-1:0] mult_a = local_en ? activation_reg : {A_W{1'b0}};
    wire signed [W_W-1:0] mult_b = local_en ? weight_reg     : {W_W{1'b0}};

    // multiplier product width: extend to PSUM_W to match accumulation
    wire signed [PSUM_W-1:0] mult_prod;
    // sign-extend multiplicands to PSUM_W, then multiply (synthesizable)
    wire signed [PSUM_W-1:0] mult_a_ext = {{(PSUM_W-A_W){activation_reg[A_W-1]}}, activation_reg};
    wire signed [PSUM_W-1:0] mult_b_ext = {{(PSUM_W-W_W){weight_reg[W_W-1]}},     weight_reg};

    assign mult_prod = mult_a_ext * mult_b_ext;

    // We will compute next_psum depending on skip and local_en
    wire signed [PSUM_W-1:0] next_psum;
    assign next_psum = (local_en && !skip_mac) ? (partial_sum_in + mult_prod) :
                       (local_en && skip_mac)  ? partial_sum_in : // no change if skip but enabled
                       partial_sum_out; // hold when not enabled

    // Sequential logic
    always @(posedge clk) begin
        if (rst) begin
            activation_reg  <= {A_W{1'b0}};
            weight_reg      <= {W_W{1'b0}};
            activation_out  <= {A_W{1'b0}};
            weight_out      <= {W_W{1'b0}};
            partial_sum_out <= {PSUM_W{1'b0}};
        end else begin
            // Capture inputs into registers only when local_en asserted.
            // This is operand gating: registers don't toggle when disabled.
            if (local_en) begin
                activation_reg <= activation_in;
                weight_reg     <= weight_in;
            end else begin
                activation_reg <= activation_reg; // hold
                weight_reg     <= weight_reg;     // hold
            end

            // Pass stream to next PE irrespective of local_en OR only when desired?
            // We choose to pass activation/weight_out as the incoming values so downstream PEs receive them.
            // If you want to prevent upstream toggles, you can choose to hold output when !local_en.
            activation_out <= activation_in;
            weight_out     <= weight_in;

            // Update partial sum:
            // - If local_en && not skip => accumulate product
            // - If local_en && skip => keep partial_sum_in (no operation)
            // - If !local_en => hold existing partial_sum_out (no update)
            if (local_en) begin
                if (!skip_mac) partial_sum_out <= partial_sum_in + mult_prod;
                else            partial_sum_out <= partial_sum_in; // skip multiply when operand zero
            end else begin
                partial_sum_out <= partial_sum_out; // hold
            end
        end
    end

endmodule
