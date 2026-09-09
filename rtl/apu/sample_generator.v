module sample_generator #(
    parameter CLOCK_HZ = 2097152 // クロック動作周波数
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_dac_enable, // DAC有効フラグセット
    input wire i_dac_enable, // DAC有効フラグ
    input wire i_we_length_timer, // 長さタイマーセット
    input wire [5:0] i_initial_timer, // 長さタイマーの初期タイマー値
    input wire i_we_output_level, // 出力レベルセット
    input wire [1:0] i_output_level, // 出力レベル設定値
    input wire i_we_period_low, // 周期下位ビットセット
    input wire [7:0] i_period_low, // 周期下位ビット
    input wire i_we_wave_ram, // サンプルセット
    input wire [4:0] i_wave_even_index, // サンプルインデックス（偶数のみ）
    input wire [7:0] i_wave_2pcm, // 2つのサンプル値(4bit x 2)
    input wire i_we_period_high_control, // 周期上位ビット・制御フラグ設定
    input wire [2:0] i_period_high, // 周期上位ビット
    input wire i_length_timer_enable, // 長さタイマー有効
    input wire i_trigger, // トリガー信号
    output reg o_enable, // 有効か？
    output reg o_dac_enable, // DAC有効か？
    output wire [3:0] o_signal // 出力信号
);

    localparam SAMPLE_GENERATOR_CLOCK_HZ = 2097152; // サンプルジェネレータのクロック動作周波数
    localparam CLK_UPDATE_COUNT_PERIOD = CLOCK_HZ / SAMPLE_GENERATOR_CLOCK_HZ; // クロックの更新周期

    wire timer_expired; // 時間切れか？
    wire length_timer_trigger; // 長さタイマーのトリガー信号

    reg [15:0] clk_count; // クロックカウント
    reg [15:0] clk_sample_update_period; // サンプル更新周期
    reg [2:0] level_shift; // 音量シフト量
    reg [10:0] period; // 周期
    reg [3:0] wave_ram[0:31]; // 波形RAM 4bit x 32サンプル
    reg [4:0] wave_ram_index; // 波形RAM参照インデックス

    length_timer #(
        .CLOCK_HZ(CLOCK_HZ)
    ) timer (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_enable(i_we_period_high_control),
        .i_enable(i_length_timer_enable),
        .i_we_length_timer(i_we_length_timer),
        .i_initial_timer_count({2'b00, i_initial_timer}),
        .i_timeout(16'd256),
        .i_trigger(length_timer_trigger),
        .o_expired(timer_expired)
    );

    // サンプルジェネレータのトリガー信号
    assign trigger = i_we_period_high_control & i_trigger;
    // 長さタイマーのトリガー信号
    assign length_timer_trigger = trigger & timer_expired;

    // DAC有効フラグ設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_dac_enable <= 0;
        end else if (i_we_dac_enable) begin
            o_dac_enable <= i_dac_enable;
        end
    end

    // 出力レベル設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            level_shift <= 4;
        end else if (i_we_output_level) begin
            case (i_output_level)
                2'd0: level_shift <= 4;
                2'd1: level_shift <= 0;
                2'd2: level_shift <= 1;
                2'd3: level_shift <= 2;
                default: level_shift <= 4;
            endcase
        end
    end

    // 更新周期（ピッチ周期）設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            period <= 0;
        end else if (i_we_period_low) begin
            period <= {period[10:8], i_period_low};
        end else if (i_we_period_high_control) begin
            period <= {i_period_high, period[7:0]};
        end
    end
    
    // 波形RAM設定
    integer i;
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            // RAMを全てリセット
            for (i = 0; i < 32; i = i + 1) begin
                wave_ram[i] <= 4'd0;
            end
        end else if (i_we_wave_ram) begin
            wave_ram[i_wave_even_index + 0] <= i_wave_2pcm[7:4];
            wave_ram[i_wave_even_index + 1] <= i_wave_2pcm[3:0];
        end
    end

    // トリガー・カウントアップ
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_enable <= 0;
            wave_ram_index <= 0;
            clk_count <= 1;
            clk_sample_update_period <= 1;
        end else if (trigger) begin
            // トリガー
            o_enable <= 1;
            wave_ram_index <= 1;
            clk_count <= 1;
            // トリガーと同時にピッチ周期上位ビットを設定する場合があるためピッチをこの場で計算
            clk_sample_update_period <= 12'd2048 - {i_period_high, period[7:0]};
        end else if (timer_expired | !o_dac_enable) begin
            // タイマー時間切れ・DAC無効
            o_enable <= 0;
        end else if (o_enable) begin
            // カウントアップ
            if (clk_count >= clk_sample_update_period) begin
                wave_ram_index <= wave_ram_index + 1;
                // 周期変更はサンプル更新後
                clk_sample_update_period <= 12'd2048 - period;
                clk_count <= 1;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

    // 出力信号
    assign o_signal = wave_ram[wave_ram_index] >> level_shift;

endmodule
