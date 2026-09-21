`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_sm83;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg [7:0] r_data;
    wire [15:0] address;
    wire [7:0] w_data;
    wire re;
    wire we;

    sm83 cpu (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_r_data(r_data),
        .o_address(address),
        .o_w_data(w_data),
        .o_re(re),
        .o_we(we)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    // リセットタスク
    task automatic sm83_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;
        end
    endtask

    initial begin
        $dumpfile("build/test_sm83.vcd");
        $dumpvars(0, test_sm83);

        clk = 0;

        sm83_reset();

        $finish;
    end
endmodule
