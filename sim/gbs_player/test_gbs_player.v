`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_gbs_player;
    parameter STEP = 10;
    localparam SIGNAL_BIT_WIDTH = 16;
    localparam CLOCK_HZ = 4194304;
    localparam AUDIO_HZ = 48000;
    localparam AUDIO_OUTPUT_PERIOD = CLOCK_HZ / AUDIO_HZ;

    reg clk;
    reg rst_n;
    wire signed [SIGNAL_BIT_WIDTH-1:0] l_signal;
    wire signed [SIGNAL_BIT_WIDTH-1:0] r_signal;
    reg [31:0] clk_count;
    integer fd;

    always #(STEP/2) begin
        clk = ~clk;
    end

    // オーディオ出力
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count <= 1;
        end else begin
            if (clk_count >= AUDIO_OUTPUT_PERIOD) begin
                if (fd != 0) begin
                    $fwrite(fd, "%c%c%c%c",
                        l_signal[7:0],
                        l_signal[15:8],
                        r_signal[7:0],
                        r_signal[15:8]);
                end
                clk_count <= 1;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

    gbs_player #(
        .CLOCK_HZ(CLOCK_HZ),
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

    // GBSファイルの読み込み・プレイテスト
    task automatic gbs_load_and_play_test(
        input [8*128-1:0] gbs_image_path
    );
        begin
            gbs_player_reset();
            $readmemh(gbs_image_path, player.memory.rom);

            // PCの設定
            player.cpu.pc = 16'h0000;
            // FIXME: タイミングが悪いと先頭の命令の読み込みが間に合わないので
            player.clk_div = 2'd1;

            repeat (1000000) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("build/test_gbs_player.vcd");
        $dumpvars(0, test_gbs_player);
        fd = $fopen("build/audio_raw_out.raw", "wb");

        clk = 0;

        gbs_player_reset();
        gbs_load_and_play_test("testdata/sm83/pkred_rom.hex");

        $fclose(fd);
        $finish;
    end
endmodule
