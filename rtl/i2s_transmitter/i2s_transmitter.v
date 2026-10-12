`timescale 1ns/1ns

// I2S送信器モジュール
// https://github.com/sipeed/TangNano-20K-example/blob/main/audio/src/audio_drive.v を参考に作成
module i2s_transmitter #(
    parameter BITS_PER_SAMPLE = 16 // 出力サンプルビット深度
) (
    input wire i_clk, // ビットクロック。1サンプルあたり左右で2 * BITS_PER_SAMPLEクロック 2 * BITS_PER_SAMPLE * Fs Hzである必要がある
    input wire i_rst_n, // Lowアクティブの非同期リセット信号
    input wire signed [BITS_PER_SAMPLE-1:0] i_l_data, // 左入力データ
    input wire signed [BITS_PER_SAMPLE-1:0] i_r_data, // 右入力データ
    output reg o_req, // データ要求信号。これがHIGHになった次のクロックでデータを取り込む
    // オーディオインターフェース
    output wire o_bck, // ビットクロック。i_clkと同じ
    output reg o_ws, // 左右チャンネル切り替え信号（0: 左, 1: 右）
    output reg o_sd // シリアルデータ出力
);

    reg [7:0] b_cnt; // ビットカウンタ
    reg req_d1; // req_rを1クロック遅延させた信号
    reg [BITS_PER_SAMPLE-1:0] l_data_buffer; // 左入力データ。シリアル出力に利用
    reg [BITS_PER_SAMPLE-1:0] r_data_buffer; // 右入力データ。シリアル出力に利用
    
    assign o_bck = i_clk;
    
    // ビットカウンタ
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            b_cnt <= 8'd0;
        end else begin
            // 2サンプル分（左右チャンネル）のクロックでリセット
            if (b_cnt >= (2 * BITS_PER_SAMPLE - 1)) begin
                b_cnt <= 8'd0;
            end else begin
                b_cnt <= b_cnt + 8'd1;
            end
        end
    end
    
    // データ要求信号
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_req <= 1'b0;
            req_d1 <= 1'b0;
        end else begin
            // カウンタがリセットされるたびに新しいデータを要求
            o_req <= (b_cnt == 8'd0);
            req_d1 <= o_req;
        end
    end
    
    // 入力データ保持・シリアル化
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            l_data_buffer <= 0;
            r_data_buffer <= 0;
        end else begin
            // データ要求の1クロック後に新しいデータを読み込み、
            // それ以外では左シフトしながらシリアル出力
            if (req_d1) begin
                l_data_buffer <= i_l_data;
                r_data_buffer <= i_r_data;
            end else if (o_ws == 1'b0) begin
                l_data_buffer <= l_data_buffer << 1;
            end else begin
                r_data_buffer <= r_data_buffer << 1;
            end
        end
    end
    
    // 左右チャンネル選択信号
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_ws <= 1'b0;
        end else begin
            // データ位置に合わせて左右チャンネルを切り替える
            // BITS_PER_SAMPLE = 16の例
            // b_cnt | posedge前の状態 |   posedge後のo_sd | コメント
            //     0 |                 | r_data_buffer[ 2] | データ要求
            //     1 |      o_req == 1 | r_data_buffer[ 1] | 外部モジュールが要求を検知
            //     2 |     req_d1 == 1 | r_data_buffer[ 0] | データ読み込み、r_data_buffer[0]は読み込み前の値
            //     3 |       o_ws == 0 | l_data_buffer[15] | データ読み込み完了、左チャンネル送信開始（WS==0としてから1クロック空ける必要がある。それはposedge前で0になっておりposedge後にLチャンネルデータが確定するので問題ない）
            //     4 |                 | l_data_buffer[14] |
            //     5 |                 | l_data_buffer[13] |
            o_ws <= (b_cnt == 8'd2) ? 1'b0
                : (b_cnt == (8'd2 + BITS_PER_SAMPLE)) ? 1'b1
                : o_ws;
        end
    end
    
    // シリアルデータ出力
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_sd <= 1'b0;
        end else begin
            // MSBから順に出力
            o_sd <= (o_ws == 0) ? l_data_buffer[BITS_PER_SAMPLE-1] : r_data_buffer[BITS_PER_SAMPLE-1];
        end
    end

endmodule
