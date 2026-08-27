module length_timer #(
    parameter CLOCK_HZ = 1048576 // クロック動作周波数
)(
    input clk,   // クロック
    input rst_n, // 非同期リセット
    input we, // パラメータ書き込み
    input trigger, // トリガー信号
    input i_enable, // 有効か
    input [7:0] i_initial_length_timer, // タイマー初期値
    input [15:0] i_timeout, // タイムアウト
    output o_expired // タイマー時間切れ
);

    localparam APU_LENGTH_TIMER_UPDATE_PERIOD_HZ = 256; // 持続時間タイマーの更新頻度
    localparam CLK_UPDATE_COUNT_PERIOD = CLOCK_HZ / APU_LENGTH_TIMER_UPDATE_PERIOD_HZ; // クロックの更新周期

    reg expired;
    reg enable;
    reg [7:0] initial_length_timer; // 長さタイマー初期値
    reg [15:0] length_timer; // タイマーカウント
    reg [15:0] timeout; // タイムアウトカウント
    reg [15:0] clk_count; // クロックカウント

    assign o_expired = expired;

    // 内部レジスタ更新
    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n) begin
            enable <= 0;
            initial_length_timer <= 0;
            timeout <= 0;
        end else if (we) begin
            enable <= i_enable;
            initial_length_timer <= i_initial_length_timer;
            timeout <= i_timeout;
        end
    end

    // トリガー
    always @(posedge clk)
    begin
        if (trigger) begin
            length_timer <= initial_length_timer;
            expired <= 0;
            clk_count <= 0;
        end
    end

    // カウントアップ
    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n) begin
            expired <= 0;
            clk_count <= 0;
            length_timer <= 0;
        end else if (enable & !expired) begin
            clk_count <= clk_count + 1;
            if (clk_count >= CLK_UPDATE_COUNT_PERIOD) begin
                length_timer <= length_timer + 1;
                if (length_timer >= timeout) begin
                    expired <= 1;
                end
                clk_count <= 0;
            end
        end
    end

endmodule
