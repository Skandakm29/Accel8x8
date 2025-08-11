// author: K M Skanda
// email: kmskanda29@gmail.com
// systolic_array.v
// 8x8 systolic array of low-power MACs with hierarchical gating.

`include "mac_unit.v"  // Use your enhanced mac_unit_lp_adv renamed to mac_unit

module systolic_array #(
    parameter N = 8,              // Array dimension
    parameter A_W = 8,            // Activation width
    parameter W_W = 8,            // Weight width
    parameter PSUM_W = 24         // Partial sum width
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        en,       // Global enable
    input  wire [N-1:0]                row_en,   // Per-row enables
    input  wire [N-1:0]                col_en,   // Per-column enables

    // Activation input for first column (from left)
    input  wire signed [A_W-1:0]       activation_in [0:N-1],
    // Weight input for first row (from top)
    input  wire signed [W_W-1:0]       weight_in [0:N-1],

    // Partial sum outputs from last column (final result)
    output wire signed [PSUM_W-1:0]    result_out [0:N-1][0:N-1]
);

    // Internal signals for interconnect
    wire signed [A_W-1:0] act_sig [0:N][0:N-1];   // One extra row for input
    wire signed [W_W-1:0] wgt_sig [0:N-1][0:N];   // One extra col for input
    wire signed [PSUM_W-1:0] psum_sig [0:N-1][0:N-1];

    genvar r, c;

    // Assign first column activation inputs
    generate
        for (r = 0; r < N; r = r + 1) begin
            assign act_sig[0][r] = activation_in[r];
        end
    endgenerate

    // Assign first row weight inputs
    generate
        for (c = 0; c < N; c = c++) begin
            assign wgt_sig[c][0] = weight_in[c];
        end
    endgenerate

    // Instantiate MACs
    generate
        for (r = 0; r < N; r = r + 1) begin : row_loop
            for (c = 0; c < N; c = c + 1) begin : col_loop
                mac_unit #(.A_W(A_W), .W_W(W_W), .PSUM_W(PSUM_W)) pe (
                    .clk(clk),
                    .rst(rst),
                    .en(en),
                    .row_en(row_en[r]),
                    .col_en(col_en[c]),
                    .activation_in(act_sig[c][r]),   // from left neighbor or input
                    .weight_in(wgt_sig[r][c]),       // from top neighbor or input
                    .activation_out(act_sig[c+1][r]),
                    .weight_out(wgt_sig[r][c+1]),
                    .partial_sum_in((c == 0) ? {PSUM_W{1'b0}} : psum_sig[r][c-1]),
                    .partial_sum_out(psum_sig[r][c])
                );

                assign result_out[r][c] = psum_sig[r][c];
            end
        end
    endgenerate

endmodule
