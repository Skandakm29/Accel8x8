`timescale 1ns/1ps
`include "mac_unit.v"  // or change to "mac_unit_lp_adv.v"

module mac_unit_tb;
    reg clk, rst;
    reg en, row_en, col_en;
    reg signed [7:0] activation_in, weight_in;
    reg signed [23:0] partial_sum_in;
    wire signed [7:0] activation_out, weight_out;
    wire signed [23:0] partial_sum_out;

    // Instantiate DUT
    mac_unit dut (
        .clk(clk), .rst(rst),
        .en(en), .row_en(row_en), .col_en(col_en),
        .activation_in(activation_in),
        .weight_in(weight_in),
        .activation_out(activation_out),
        .weight_out(weight_out),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("mac_unit_tb.vcd");
        $dumpvars(0, mac_unit_tb); // match testbench name

        clk = 0; rst = 1;
        en = 1; row_en = 0; col_en = 0;
        activation_in = 0; weight_in = 0; partial_sum_in = 0;
        
        // Reset phase
        #20 rst = 0;

        // Basic MAC
        en = 1; row_en = 1; col_en = 1;
        activation_in = 8'sd3; weight_in = 8'sd4; partial_sum_in = 24'sd10;
        #10;
        $display("Test1: %0d", partial_sum_out); // Expect 22

        // Sparsity skip (activation=0)
        activation_in = 8'sd0; weight_in = 8'sd5; partial_sum_in = 24'sd50;
        #10;
        $display("Test2: %0d", partial_sum_out); // Expect 50

        // Disable PE
        en = 0; activation_in = 8'sd2; weight_in = 8'sd3; partial_sum_in = 24'sd100;
        #10;
        $display("Test3: %0d", partial_sum_out); // Expect unchanged

        $finish;
    end
endmodule
