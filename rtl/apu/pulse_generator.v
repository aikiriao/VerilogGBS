module pulse_generator #(
    parameter CLOCK_HZ = 2097152 // クロック動作周波数
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_period_sweep, // スイープセット
    input wire [2:0] i_period_sweep_pace, // スイープ速度
    input wire i_period_sweep_direction, // スイープ方向（0: 正, 1: 負）
    input wire [2:0] i_period_sweep_step, // スイープステップ
    input wire i_we_length_timer_duty_ratio, // 長さタイマー・デューティセット
    input wire [5:0] i_initial_timer, // 長さタイマーの初期タイマー値
    input wire [1:0] i_duty_ratio, // デューティ比
    input wire i_we_volume_envelope, // エンベロープセット
    input wire [3:0] i_initial_volume, // 初期ボリューム
    input wire i_volume_delta_direction, // ボリューム更新方向（0: -1、1: 1）
    input wire [2:0] i_volume_sweep_pace, // ボリューム更新スピード
    input wire i_we_period_low, // 周期下位ビットセット
    input wire [7:0] i_period_low, // 周期下位ビット
    input wire i_we_period_high_control, // 周期上位ビット・制御フラグ設定
    input wire [2:0] i_period_high, // 周期上位ビット
    input wire i_length_timer_enable, // 長さタイマー有効
    input wire i_trigger, // トリガー信号
    output reg o_enable, // 有効か？
    output reg o_dac_enable, // DAC有効か？
    output wire [3:0] o_signal // 出力信号
);

    localparam PULSE_GENERATOR_CLOCK_HZ = 1048576; // サンプルジェネレータのクロック動作周波数
    localparam CLK_UPDATE_COUNT_PERIOD = CLOCK_HZ / PULSE_GENERATOR_CLOCK_HZ; // クロックの更新周期
    localparam SWEEP_UPDATE_PERIOD_UNIT_HZ = 128; // スイープの更新頻度単位

    wire [3:0] eg_volume; // 出力ボリューム
    wire timer_expired; // 時間切れか？
    wire length_timer_trigger; // 長さタイマーのトリガー信号

    reg [15:0] clk_count; // クロックカウント
    reg [15:0] clk_sample_update_period; // サンプル更新周期
    reg [10:0] period; // 周期
    reg period_changed; // 周期が変更されたか
    reg period_update_enable; // 周期変更するか
    reg period_sweep_direction; // 周期変更方向（0: 正, 1: 負）
    reg [7:0] period_sweep_step; // 周期変更ステップ
    reg [15:0] period_update_period; // 周期更新間隔
    reg [15:0] period_update_count; // 周期更新カウント
    reg [1:0] duty_ratio; // デューティ比
    reg [2:0] pulse_table_index; // 矩形波テーブルのインデックス

    envelope_generator #(
        .CLOCK_HZ(CLOCK_HZ)
    ) eg (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we(i_we_volume_envelope),
        .i_volume_delta_direction(i_volume_delta_direction),
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
        .i_we_enable(i_we_period_high_control),
        .i_enable(i_length_timer_enable),
        .i_we_length_timer(i_we_length_timer_duty_cycle),
        .i_initial_timer_count({2'b00, i_initial_timer}),
        .i_timeout(16'd64),
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
        end else if (i_we_volume_envelope) begin
            o_dac_enable <= (i_initial_volume != 0) | i_volume_delta_direction;
        end
    end

    // スイープ設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            period_sweep_direction <= 0;
            period_sweep_step <= 0;
            period_update_enable <= 0;
            period_update_period <= 0;
        end else if (i_we_period_sweep) begin
            period_sweep_direction <= i_period_sweep_direction;
            period_sweep_step <= i_period_sweep_step;
            if (i_period_sweep_pace > 0) begin
                case (i_period_sweep_pace)
                    3'd1: period_update_period <= PULSE_GENERATOR_CLOCK_HZ / (1 * SWEEP_UPDATE_PERIOD_UNIT_HZ);
                    3'd2: period_update_period <= PULSE_GENERATOR_CLOCK_HZ / (2 * SWEEP_UPDATE_PERIOD_UNIT_HZ);
                    3'd3: period_update_period <= PULSE_GENERATOR_CLOCK_HZ / (3 * SWEEP_UPDATE_PERIOD_UNIT_HZ);
                    3'd4: period_update_period <= PULSE_GENERATOR_CLOCK_HZ / (4 * SWEEP_UPDATE_PERIOD_UNIT_HZ);
                    3'd5: period_update_period <= PULSE_GENERATOR_CLOCK_HZ / (5 * SWEEP_UPDATE_PERIOD_UNIT_HZ);
                    3'd6: period_update_period <= PULSE_GENERATOR_CLOCK_HZ / (6 * SWEEP_UPDATE_PERIOD_UNIT_HZ);
                    3'd7: period_update_period <= PULSE_GENERATOR_CLOCK_HZ / (7 * SWEEP_UPDATE_PERIOD_UNIT_HZ);
                    default: period_update_period <= 0;
                endcase
            end
            period_update_enable <= (i_period_sweep_pace > 0);
        end
    end

    // デューティ比の設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            duty_ratio <= 0;
        end else if (i_we_length_timer_duty_ratio) begin
            duty_ratio <= i_duty_ratio;
        end
    end

    // 更新周期（ピッチ周期）設定
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            period <= 0;
            period_changed <= 0;
        end else if (i_we_period_low) begin
            period <= {period[10:8], i_period_low};
            period_changed <= 1;
        end else if (i_we_period_high_control) begin
            period <= {i_period_high, period[7:0]};
            period_changed <= 1;
        end
    end

    // 周期更新
    wire [11:0] extend_period;
    assign extend_period = (period_sweep_direction)
                    ? (period - (period >> period_sweep_step))
                    : (period + (period >> period_sweep_step));
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            period_update_count <= 1;
        end else if (o_enable & period_update_enable) begin
            if (period_update_count >= clk_sample_update_period) begin
                period <= extend_period[10:0];
                // オーバーフロー時はチャンネルを無効に
                if (extend_period[11]) begin
                    o_enable <= 0;
                    period_update_enable <= 0;
                end
                period_update_count <= 1;
            end else begin
                period_update_count <= period_update_count + 1;
            end
        end
    end

    // トリガー・カウントアップ
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_enable <= 0;
            pulse_table_index <= 0;
            clk_count <= 1;
            clk_sample_update_period <= 1;
        end else if (timer_expired | !o_dac_enable) begin
            // タイマー時間切れ・DAC無効
            o_enable <= 0;
        end else if (trigger) begin
            // トリガー
            o_enable <= 1;
            pulse_table_index <= 0;
            clk_count <= 1;
            // トリガーと同時にピッチ周期上位ビットを設定する場合があるためピッチをこの場で計算
            clk_sample_update_period <= 12'd2048 - {i_period_high, period[7:0]};
        end else if (o_enable) begin
            // カウントアップ
            if (clk_count >= clk_sample_update_period) begin
                pulse_table_index <= pulse_table_index + 1;
                // 周期変更はサンプル更新後
                if (period_changed) begin
                    clk_sample_update_period <= 12'd2048 - period;
                    period_changed <= 0;
                end
                clk_count <= 1;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

    // 矩形波テーブルの値を得る
    function pulse_table(
        input [1:0] duty_ratio,
        input [2:0] pulse_table_index
    );
    begin
        case (duty_ratio)
            2'd0: // 12.5%
                case (pulse_table_index)
                    3'd0: pulse_table = 1;
                    3'd1: pulse_table = 1;
                    3'd2: pulse_table = 1;
                    3'd3: pulse_table = 1;
                    3'd4: pulse_table = 1;
                    3'd5: pulse_table = 1;
                    3'd6: pulse_table = 1;
                    3'd7: pulse_table = 0;
                    default: pulse_table = 0;
                endcase
            2'd1: // 25.0%
                case (pulse_table_index)
                    3'd0: pulse_table = 0;
                    3'd1: pulse_table = 1;
                    3'd2: pulse_table = 1;
                    3'd3: pulse_table = 1;
                    3'd4: pulse_table = 1;
                    3'd5: pulse_table = 1;
                    3'd6: pulse_table = 1;
                    3'd7: pulse_table = 0;
                    default: pulse_table = 0;
                endcase
            2'd2: // 50.0%
                case (pulse_table_index)
                    3'd0: pulse_table = 0;
                    3'd1: pulse_table = 1;
                    3'd2: pulse_table = 1;
                    3'd3: pulse_table = 1;
                    3'd4: pulse_table = 1;
                    3'd5: pulse_table = 0;
                    3'd6: pulse_table = 0;
                    3'd7: pulse_table = 0;
                    default: pulse_table = 0;
                endcase
            2'd3: // 75.0%
                case (pulse_table_index)
                    3'd0: pulse_table = 1;
                    3'd1: pulse_table = 0;
                    3'd2: pulse_table = 0;
                    3'd3: pulse_table = 0;
                    3'd4: pulse_table = 0;
                    3'd5: pulse_table = 0;
                    3'd6: pulse_table = 0;
                    3'd7: pulse_table = 1;
                    default: pulse_table = 0;
                endcase
            default: pulse_table = 0;
        endcase
    end
    endfunction

    // 出力信号
    assign o_signal = pulse_table(duty_ratio, pulse_table_index) ? eg_volume : 0;

endmodule
