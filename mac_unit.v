//
module mac_unit (
    input clk,
    input rst,
    input [7:0] activation_in,
    input [7:0] weight_in,
    output reg [7:0] activation_out,
    output reg [7:0] weight_out,
    input signed [23:0] partial_sum_in,
    output reg signed [23:0] partial_sum_out
);

always @(posedge clk ) begin
    if (rst) begin
        activation_out <= 0;
        weight_out <= 0;
        partial_sum_out <= 0;
    end else begin
        activation_out <= activation_in;           // Pass activation to next PE
        weight_out <= weight_in;                   // Pass weight to next PE
        partial_sum_out <= partial_sum_in + $signed(activation_in) * $signed(weight_in);  // MAC operation
    end
end

endmodule
// mac_unit.v - Multiply-Accumulate Unit for MAC Array