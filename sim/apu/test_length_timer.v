`timescale 1ns/1ns

module test_length_timer;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg enable;
    reg we;
    reg [7:0] initial_length_timer;
    reg [15:0] timeout;
    wire expired;

    length_timer #(
        .CLOCK_HZ(256)
    ) timer(
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .i_enable(enable),
        .i_initial_length_timer(initial_length_timer),
        .i_timeout(timeout),
        .o_expired(expired)
    );

    always #(STEP/2) begin
        clk <= ~clk;
    end

    initial begin
        $dumpfile("build/test_length_timer.vcd");
        $dumpvars(0, test_length_timer);

        clk <= 0;

        // リセット
        rst_n <= 0;
        #STEP
        rst_n <= 1;
        #STEP

        // パラメータセット
        enable <= 1;
        initial_length_timer <= 1;
        timeout <= 1;
        we <= 1;
        #STEP

        #(STEP * 10)

        $finish;
    end
endmodule
