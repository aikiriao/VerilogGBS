`timescale 1ns/1ns

module test_length_timer;
    // 仮
    reg tb_a;
    reg tb_b;
    wire tb_y;

    length_timer uut (
        .a(tb_a),
        .b(tb_b),
        .y(tb_y)
    );

    initial begin
        $dumpfile("build/test_length_timer.vcd");
        $dumpvars(0, test_length_timer);

        tb_a = 0; tb_b = 0;
        #10;
        tb_a = 0; tb_b = 1;
        #10;
        tb_a = 1; tb_b = 0;
        #10;
        tb_a = 1; tb_b = 1;
        #10;
        $finish;
    end
endmodule
