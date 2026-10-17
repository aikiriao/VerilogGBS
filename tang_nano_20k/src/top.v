module top (
    input wire i_clk, // クロック
    input wire i_rst, // 非同期リセット
    input wire i_next_button, // 楽曲変更ボタン
    input wire i_prev_button, // 楽曲変更ボタン

    // オーディオインターフェース
    output wire o_i2s_bck, // 1.536 MHzクロックと同じ
    output wire o_i2s_ws, // 左右チャンネル切り替え信号（Low: 左チャンネル）
    output wire o_i2s_din, // DACへのシリアルデータ入力信号
    output wire o_i2s_en // オーディオアンプ有効信号（Highアクティブ）
);

    localparam BITS_PER_SAMPLE = 16;

    `include "gbs_player_joypad_command.vh"

    wire clk_6m; // 1.5 MHzクロック生成用の6 MHzクロック
    wire clk_1p5m; // 約1.536 MHzのクロック
    wire data_req; // データ読み出し要求
    wire rst_n = ~i_rst;
    wire signed [BITS_PER_SAMPLE-1:0] l_signal;
    wire signed [BITS_PER_SAMPLE-1:0] r_signal;

    reg we_command;
    reg [7:0] command;

    assign o_i2s_en = 1'b1; // オーディオアンプは常時有効

    Gowin_rPLL pll_27m_6m(
        .clkin(i_clk),
        .clkout(clk_6m)
    );

    Gowin_CLKDIV clk_div4(
        .resetn(rst_n), // Lowアクティブリセット
        .hclkin(clk_6m), // 入力クロック
        .clkout(clk_1p5m) // 出力クロック
    );

    // I2S送信器
    i2s_transmitter #(
        .BITS_PER_SAMPLE(BITS_PER_SAMPLE)
    ) i2s_tx (
        .i_clk(clk_1p5m), // ビットクロック
        .i_rst_n(rst_n), // 非同期リセット信号
        .i_l_data(l_signal), // 左チャンネルデータ
        .i_r_data(r_signal), // 右チャンネルデータ
        .o_req(data_req), // データ要求信号
        .o_bck(o_i2s_bck), // 1.536 MHzクロックと同じ
        .o_ws(o_i2s_ws), // 左右チャンネル切り替え信号（Low: 左チャンネル）
        .o_sd(o_i2s_din) // DACへのシリアルデータ入力信号
    );

    // GBSプレイヤー
    gbs_player #(
        .ROM_FILE("testdata/gbs_player/pkred_rom.hex"),
        .CLOCK_HZ(27_000_000),
        .SIGNAL_BIT_WIDTH(BITS_PER_SAMPLE)
    ) player (
        .i_clk(i_clk), // クロック
        .i_rst_n(rst_n), // 非同期リセット信号
        .i_we_command(we_command),
        .i_command(command),
        .o_l_signal(l_signal),
        .o_r_signal(r_signal)
    );

    always @(posedge i_clk or negedge rst_n)
    begin
        if (!rst_n) begin
            we_command <= 0;
            command <= 8'd0;
        end else if (i_next_button) begin
            we_command <= 1;
            command <= JOYPAD_COMMAND_NEXT_SONG;
        end else if (i_prev_button) begin
            we_command <= 1;
            command <= JOYPAD_COMMAND_PREV_SONG;
        end else begin
            we_command <= 0;
            command <= 8'd0;
        end
    end

endmodule
