`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_gbs_player;
    parameter STEP = 10;
    parameter SIGNAL_BIT_WIDTH = 16;
    reg clk;
    reg rst_n;
    wire signed [SIGNAL_BIT_WIDTH-1:0] l_signal;
    wire signed [SIGNAL_BIT_WIDTH-1:0] r_signal;

    always #(STEP/2) begin
        clk = ~clk;
    end

    gbs_player #(
        .SIGNAL_BIT_WIDTH(SIGNAL_BIT_WIDTH)
    ) player (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .o_l_signal(l_signal),
        .o_r_signal(r_signal)
    );

    // リセットタスク
    task automatic gbs_player_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;
        end
    endtask

    // ポケモン赤のテスト
    task automatic gbs_player_pkred_test;
        begin
            gbs_player_reset();
            $readmemh("testdata/sm83/pkred_rom.hex", player.memory.rom);

            // PCの設定
            player.cpu.pc = 16'h0000;
            // FIXME: タイミングが悪いと先頭の命令の読み込みが間に合わないので
            player.clk_div = 2'd1;

            repeat (100000) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("build/test_gbs_player.vcd");
        $dumpvars(0, test_gbs_player);

        clk = 0;

        gbs_player_reset();
        gbs_player_pkred_test();

        $finish;
    end
endmodule
