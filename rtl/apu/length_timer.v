module length_timer #(
    parameter CLOCK_HZ = 1048576 // クロック動作周波数
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_enable, // 長さタイマー有効フラグ書き込み
    input wire i_enable, // 有効か
    input wire i_we_length_timer, // 長さタイマーパラメータ書き込み
    input wire [7:0] i_initial_timer_count, // タイマー初期値
    input wire [15:0] i_timeout, // タイムアウト
    input wire i_trigger, // トリガー信号
    output reg o_expired // タイマー時間切れ
);

    localparam APU_LENGTH_TIMER_UPDATE_PERIOD_HZ = 256; // 持続時間タイマーの更新頻度
    localparam CLK_UPDATE_COUNT_PERIOD = CLOCK_HZ / APU_LENGTH_TIMER_UPDATE_PERIOD_HZ; // クロックの更新周期

    reg enable; // タイマー有効か
    reg [7:0] initial_timer_count; // 長さタイマー初期値
    reg [15:0] timer_count; // タイマーカウント
    reg [15:0] timeout; // タイムアウトカウント
    reg [15:0] clk_count; // クロックカウント

    // 有効フラグ更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            enable <= 0;
        end else if (i_we_enable) begin
            enable <= i_enable;
        end
    end

    // 内部レジスタ更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            initial_timer_count <= 0;
            timeout <= 0;
        end else if (i_we_length_timer) begin
            initial_timer_count <= i_initial_timer_count;
            timeout <= i_timeout;
        end
    end

    // トリガー・カウントアップ
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_expired <= 1;
            clk_count <= 1;
            timer_count <= 0;
        end else if (i_trigger) begin
            // トリガー
            o_expired <= 0;
            clk_count <= 1;
            timer_count <= initial_timer_count;
        end else if (enable & !o_expired) begin
            // カウントアップ
            if (clk_count >= CLK_UPDATE_COUNT_PERIOD) begin
                if (timer_count >= timeout) begin
                    o_expired <= 1;
                end else begin
                    clk_count <= 1;
                    timer_count <= timer_count + 1;
                end
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

endmodule
