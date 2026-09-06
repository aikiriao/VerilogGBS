module noise_generator #(
    parameter CLOCK_HZ = 2097152 // クロック動作周波数
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_length_timer, // 長さタイマーセット
    input wire [5:0] i_initial_timer, // 長さタイマーの初期タイマー値
    input wire i_we_volume_envelope, // エンベロープセット
    input wire [3:0] i_initial_volume, // 初期ボリューム
    input wire i_volume_delta_dir, // ボリューム更新方向（0: -1、1: 1）
    input wire [2:0] i_volume_sweep_pace, // ボリューム更新スピード
    input wire i_we_frequency_randomness, // 更新頻度・ランダムネスセット
    input wire [3:0] i_clock_shift, // クロックシフト
    input wire i_lfsr_mode, // LFSRのモード（0:ロング、1:ショート）
    input wire [2:0] i_clock_divider, // 更新クロック分周ファクタ
    input wire i_we_control, // 制御フラグセット
    input wire i_length_timer_enable, // 長さタイマー有効
    input wire i_trigger, // トリガー信号
    output reg o_enable, // 有効か？
    output reg o_dac_enable, // DAC有効か？
    output wire [3:0] o_signal // 出力信号
);

    localparam NOISE_GENERATOR_CLOCK_HZ = 262144; // ノイズジェネレータのクロック動作周波数
    localparam CLK_UPDATE_COUNT_PERIOD = CLOCK_HZ / NOISE_GENERATOR_CLOCK_HZ; // クロックの更新周期

    wire [3:0] eg_volume; // 出力ボリューム
    wire timer_expired; // 時間切れか？
    wire eg_trigger; // エンベロープジェネレータのトリガー信号
    wire length_timer_trigger; // 長さタイマーのトリガー信号

    reg [15:0] clk_count; // クロックカウント
    reg [15:0] clk_div_count; // 分周比カウント
    reg [15:0] clk_div_period; // 分周比更新周期
    reg [15:0] lfsr_mask; // LFSRのマスク
    reg [15:0] lfsr; // LFSRの内部状態レジスタ

    envelope_generator #(
        .CLOCK_HZ(CLOCK_HZ)
    ) eg (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we(i_we_volume_envelope),
        .i_volume_delta_dir(i_volume_delta_dir),
        .i_initial_volume(i_initial_volume),
        .i_volume_sweep_pace(i_volume_sweep_pace),
        .i_trigger(trigger),
        .o_volume(eg_volume)
    );

    length_timer #(
        .CLOCK_HZ(CLOCK_HZ)
    ) timer (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_enable(i_we_control),
        .i_enable(i_length_timer_enable),
        .i_we_length_timer(i_we_length_timer),
        .i_initial_timer_count({2'b00, i_initial_timer}),
        .i_timeout(16'd64),
        .i_trigger(length_timer_trigger),
        .o_expired(timer_expired)
    );

    // ノイズジェネレータのトリガー信号
    assign trigger = i_we_control & i_trigger;
    // 長さタイマーのトリガー信号
    assign length_timer_trigger = trigger & timer_expired;

    // 更新周期・ランダムネス設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            clk_div_period <= 0;
            lfsr_mask <= 0;
        end else if (i_we_frequency_randomness) begin
            // 分周比周期
            if (i_clock_divider == 0) begin
                clk_div_period <= (i_clock_shift == 0) ? 0 : (1 << (i_clock_shift - 1));
            end else begin
                clk_div_period <= (1 << i_clock_shift);
            end
            // LFSRのマスク
            lfsr_mask <= (i_lfsr_mode) ? 16'h8080 : 16'h8000;
        end
    end

    // DAC有効フラグ設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_dac_enable <= 0;
        end else if (i_we_volume_envelope) begin
            o_dac_enable <= (i_initial_volume != 0) | i_volume_delta_dir;
        end
    end
    
    // トリガー・カウントアップ
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_enable <= 0;
            clk_count <= 1;
            clk_div_count <= 1;
            lfsr <= 0;
        end else if (timer_expired | !o_dac_enable) begin
            // タイマー時間切れ・DAC無効
            o_enable <= 0;
        end else if (trigger) begin
            // トリガー
            o_enable <= 1;
            clk_count <= 1;
            clk_div_count <= 1;
            lfsr <= 0;
        end else if (o_enable) begin
            // カウントアップ
            if (clk_count >= CLK_UPDATE_COUNT_PERIOD) begin
                if (clk_div_count >= clk_div_period) begin
                    // LFSR状態更新
                    lfsr <= (lfsr[0] == lfsr[1]) ? ((lfsr | lfsr_mask) >> 1) : ((lfsr & (~lfsr_mask)) >> 1);
                    clk_div_count <= 1;
                end else begin
                    clk_div_count <= clk_div_count + 1;
                end
                clk_count <= 1;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

    // 出力信号
    assign o_signal = lfsr[0] ? eg_volume : 0;

endmodule
