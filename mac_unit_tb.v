`timescale 1ns/1ps
`include "mac_unit.v"
module mac_unit_tb;

    reg clk;
    reg rst;
    reg [7:0] activation_in;
    reg [7:0] weight_in;
    reg signed [23:0] partial_sum_in;

    wire [7:0] activation_out;
    wire [7:0] weight_out;
    wire signed [23:0] partial_sum_out;

    // Instantiate the MAC unit
    mac_unit uut (
        .clk(clk),
        .rst(rst),
        .activation_in(activation_in),
        .weight_in(weight_in),
        .activation_out(activation_out),
        .weight_out(weight_out),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_out)
    );

    // Clock generator
    always #5 clk = ~clk; // 100 MHz

    initial begin
        $dumpfile("mac_unit_tb.vcd");  // For waveform view
        $dumpvars(0, mac_unit_tb);

        // Init
        clk = 0;
        rst = 1;
        activation_in = 0;
        weight_in = 0;
        partial_sum_in = 0;

        // Hold reset for a bit
        #10;
        rst = 0;

        // Test case 1
        activation_in = 8'd3;
        weight_in = 8'd4;
        partial_sum_in = 24'd0;
        #10;

        // Test case 2
        activation_in = 8'd2;
        weight_in = -8'd5;  // test signed multiply
        partial_sum_in = partial_sum_out; // feed back
        #10;

        // Test case 3
        activation_in = -8'd7;
        weight_in = 8'd6;
        partial_sum_in = partial_sum_out;
        #10;

        $finish;
    end
endmodule
