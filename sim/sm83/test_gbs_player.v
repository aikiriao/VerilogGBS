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

            // TODO: 以下の再生モジュールをhexに入れる

            // SPの設定
            player.memory.rom[16'h0000] = 8'h31; // LD SP, imm16
            player.memory.rom[16'h0001] = 8'hFF; // SP設定値下位
            player.memory.rom[16'h0002] = 8'hDF; // SP設定値上位
            // TMA/TACの設定
            player.memory.rom[16'h0003] = 8'h3E; // LD A, imm8
            player.memory.rom[16'h0004] = 8'h00; // TMA設定値
            player.memory.rom[16'h0005] = 8'hE0; // LDH [0x06], A
            player.memory.rom[16'h0006] = 8'h06;
            player.memory.rom[16'h0007] = 8'h3E; // LD A, imm8
            player.memory.rom[16'h0008] = 8'h00; // TAC設定値
            player.memory.rom[16'h0009] = 8'hE0; // LDH [0x07], A
            player.memory.rom[16'h000A] = 8'h07;
            // Aの設定（再生楽曲番号）
            player.memory.rom[16'h000B] = 8'h3E; // LD A, imm8
            player.memory.rom[16'h000C] = 8'h01; // 楽曲番号
            // Initルーチン呼び出し
            player.memory.rom[16'h000D] = 8'hCD; // CALL init_address
            player.memory.rom[16'h000E] = 8'h56; // init_address下位
            player.memory.rom[16'h000F] = 8'h3F; // init_address上位
            // 割り込み有効
            // 全割り込み有効
            player.memory.rom[16'h0010] = 8'h3E; // LD A, 0x1F
            player.memory.rom[16'h0011] = 8'h1F;
            player.memory.rom[16'h0012] = 8'hE0; // LDH [0xFF], A
            player.memory.rom[16'h0013] = 8'hFF;
            player.memory.rom[16'h0014] = 8'hFB; // EI
            // 無限ループ（再生待機）
            player.memory.rom[16'h0015] = 8'h18; // JR -2
            player.memory.rom[16'h0016] = 8'hFE;
            // Playルーチンを割り込みに仕込む
            player.memory.rom[16'h0040] = 8'hCD; // CALL play_address
            player.memory.rom[16'h0041] = 8'h7E; // play_address下位
            player.memory.rom[16'h0042] = 8'h3F; // play_address上位
            player.memory.rom[16'h0043] = 8'hD9; // RETI
            player.memory.rom[16'h0050] = 8'hCD; // CALL play_address
            player.memory.rom[16'h0051] = 8'h7E; // play_address下位
            player.memory.rom[16'h0052] = 8'h3F; // play_address上位
            player.memory.rom[16'h0053] = 8'hD9; // RETI

            // PCの設定
            player.cpu.pc = 16'h0000;
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
