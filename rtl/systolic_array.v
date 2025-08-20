// 8x8 systolic array (pure Verilog-2001 version)
// - Flattened edge ports (no SV array ports)
// - Neighbor wiring via named generate blocks.
// Packing:
//   activation_in_flat: rows packed, row0 in [A_W-1:0], row1 in [2*A_W-1:A_W], ...
//   weight_in_flat:     cols packed, col0 in [W_W-1:0], col1 in [2*W_W-1:W_W], ...
//   result_flat:        row-major, index = r*N + c
// Systolic array module
// - N: number of rows/columns (square array)
// - A_W: activation width (signed)
// - W_W: weight width (signed)
// - PSUM_W: partial-sum width (signed)
// - clk: clock signal
// - rst: synchronous reset (active-high)
// - en: enable signal for the entire array
// - row_en: per-row enable signals (N bits)
// - col_en: per-column enable signals (N bits)
// - activation_in_flat: flattened input for activations (N*A_W bits)
// - weight_in_flat: flattened input for weights (N*W_W bits)
// - result_flat: flattened output for results (N*N*PSUM_W bits)
// - The array computes the matrix multiplication of activations and weights
//   and outputs the results in a flattened format.

`default_nettype none
module systolic_array #(
  parameter N       = 8,
  parameter A_W     = 8,
  parameter W_W     = 8,
  parameter PSUM_W  = 24
)(
  input                       clk,
  input                       rst,
  input                       en,
  input       [N-1:0]         row_en,
  input       [N-1:0]         col_en,
  input  signed [N*A_W-1:0]   activation_in_flat,
  input  signed [N*W_W-1:0]   weight_in_flat,
  output      [N*N*PSUM_W-1:0] result_flat
);

  // Unpack left-edge activations and top-edge weights for convenience
  wire signed [A_W-1:0] act_edge [0:N-1];
  wire signed [W_W-1:0] wgt_edge [0:N-1];

  genvar r, c;
  generate
    for (r=0; r<N; r=r+1) begin : UNPACK_A
      localparam integer A_LO = r*A_W;
      localparam integer A_HI = A_LO + A_W - 1;
      assign act_edge[r] = activation_in_flat[A_HI:A_LO];
    end
    for (c=0; c<N; c=c+1) begin : UNPACK_W
      localparam integer W_LO = c*W_W;
      localparam integer W_HI = W_LO + W_W - 1;
      assign wgt_edge[c] = weight_in_flat[W_HI:W_LO];
    end
  endgenerate

  // Instantiate PEs and connect neighbors by hierarchical names
  generate
    for (c=0; c<N; c=c+1) begin : COL
      for (r=0; r<N; r=r+1) begin : ROW
        // Local interconnect wires
        wire signed [A_W-1:0] act_in;
        wire signed [W_W-1:0] wgt_in;
        wire signed [A_W-1:0] act_out;
        wire signed [W_W-1:0] wgt_out;
        wire signed [PSUM_W-1:0] psum_in;
        wire signed [PSUM_W-1:0] psum_out;

        // Activation from left neighbor (or left edge for c==0)
        if (c==0) assign act_in = act_edge[r];
        else      assign act_in = COL[c-1].ROW[r].act_out;

        // Weight from top neighbor (or top edge for r==0)
        if (r==0) assign wgt_in = wgt_edge[c];
        else      assign wgt_in = COL[c].ROW[r-1].wgt_out;

        // Partial sum from left neighbor (or zero for first column)
        if (c==0) assign psum_in = {PSUM_W{1'b0}};
        else      assign psum_in = COL[c-1].ROW[r].psum_out;

        mac_unit #(.A_W(A_W), .W_W(W_W), .PSUM_W(PSUM_W)) PE (
          .clk(clk), .rst(rst), .en(en),
          .row_en(row_en[r]), .col_en(col_en[c]),
          .activation_in(act_in),   .weight_in(wgt_in),
          .activation_out(act_out), .weight_out(wgt_out),
          .partial_sum_in(psum_in), .partial_sum_out(psum_out)
        );

        // Pack PE result into flat row-major bus
        localparam integer IDX  = r*N + c;
        localparam integer P_LO = IDX*PSUM_W;
        localparam integer P_HI = P_LO + PSUM_W - 1;
        // Assign the output to the flattened result bus
        assign result_flat[P_HI:P_LO] = psum_out;
      end
    end
  endgenerate
endmodule
