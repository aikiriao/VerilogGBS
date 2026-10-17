module top (
    input wire i_clk, // クロック
    input wire i_rst, // 非同期リセット
    input wire i_next_button, // 楽曲変更ボタン

    // オーディオインターフェース
    output wire o_i2s_bck, // 1.536 MHzクロックと同じ
    output wire o_i2s_ws, // 左右チャンネル切り替え信号（Low: 左チャンネル）
    output wire o_i2s_din, // DACへのシリアルデータ入力信号
    output wire o_i2s_en // オーディオアンプ有効信号（Highアクティブ）
);

    localparam BITS_PER_SAMPLE = 16;
    localparam SCALE_RIGHT_SHIFT = 2; // 出力の右シフト量 フルスケールで出力すると機材が壊れる可能性があるため
    localparam DEBOUNCE_COUNT = 270_000;

    `include "gbs_player_joypad_command.vh"

    wire clk_6m; // 1.5 MHzクロック生成用の6 MHzクロック
    wire clk_1p5m; // 約1.536 MHzのクロック
    wire data_req; // データ読み出し要求
    wire rst_n = ~i_rst;

    wire signed [BITS_PER_SAMPLE-1:0] l_signal;
    wire signed [BITS_PER_SAMPLE-1:0] r_signal;
    reg signed [BITS_PER_SAMPLE-1:0] scaled_l_signal;
    reg signed [BITS_PER_SAMPLE-1:0] scaled_r_signal;

    reg next_button_d1;
    reg next_button_d2;
    reg next_button;
    reg [18:0] debounce_count;
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
        .i_l_data(scaled_l_signal), // 左チャンネルデータ
        .i_r_data(scaled_r_signal), // 右チャンネルデータ
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

    // 出力信号更新
    always @(posedge i_clk or negedge rst_n) begin
        if (!rst_n) begin
            scaled_l_signal <= 0;
            scaled_r_signal <= 0;
        end else if (data_req) begin
            // データ要求時にデータを更新
            scaled_l_signal <= l_signal >>> SCALE_RIGHT_SHIFT;
            scaled_r_signal <= r_signal >>> SCALE_RIGHT_SHIFT;
        end
    end

    // ボタン状態更新
    always @(posedge i_clk or negedge rst_n) begin
        if (!rst_n) begin
            next_button_d1 <= 0;
            next_button_d2 <= 0;
            next_button <= 0;
            debounce_count <= 19'd0;

            we_command <= 0;
            command <= 8'd0;
        end else begin
            // 同期入力化（2FF挟んでメタステーブルを極力回避）
            next_button_d1 <= i_next_button;
            next_button_d2 <= next_button_d1;

            // 送信コマンドパルスはなにもなければ0
            we_command <= 1'b0;
            command <= JOYPAD_COMMAND_NONE;

            if (next_button_d2 == next_button) begin
                debounce_count <= 19'd1;
            end else begin
                // next_buttonとは違うボタンが入ったことをカウント
                if (debounce_count >= DEBOUNCE_COUNT) begin
                    // ボタン状態を更新
                    next_button <= next_button_d2;
                    // 1 -> 0 が確定したら離したと判断
                    if (next_button && !next_button_d2) begin
                        we_command <= 1;
                        command <= JOYPAD_COMMAND_NEXT_SONG;
                    end
                    debounce_count <= 19'd1;
                end else begin
                    debounce_count <= debounce_count + 19'd1;
                end
            end
        end
    end

endmodule
