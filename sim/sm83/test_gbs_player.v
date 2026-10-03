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

    // メモリ書き込み
    task automatic gbs_player_write_memory;
        input reg [15:0] address;
        input reg [7:0] value;
        begin
            player.address = address; 
            player.cpu_w_data = value;
            player.cpu_we = 1;
            @(posedge clk);
            @(negedge clk);
            player.cpu_we = 0;
        end
    endtask

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
            gbs_player_write_memory(`HWREG_TMA_TIMER_MODULO, 0);
            gbs_player_write_memory(`HWREG_TAC_TIMER_CONTROL, 0);

            player.cpu.sp = 16'hDFFF;
            // TODO: Initルーチンを仕込む
            // player.memory.rom[0];
            // TODO: Playルーチンを割り込みに仕込む
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
