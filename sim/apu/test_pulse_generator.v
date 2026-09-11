`include "test.vh"
`timescale 1ns/1ns

module test_pulse_generator;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg we_period_sweep;
    reg we_length_timer_duty_ratio;
    reg we_volume_envelope;
    reg we_period_low;
    reg we_period_high_control;

    reg [2:0] period_sweep_pace;
    reg period_sweep_direction;
    reg [2:0] period_sweep_step;
    reg [1:0] duty_ratio;
    reg [5:0] initial_timer;
    reg [3:0] initial_volume;
    reg volume_delta_direction;
    reg [2:0] volume_sweep_pace;
    reg [7:0] period_low;
    reg [2:0] period_high;
    reg length_timer_enable;
    reg trigger;

    wire [3:0] signal;
    wire enable;
    wire dac_enable;

    pulse_generator #(
        .CLOCK_HZ(2097152)
    ) pg (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we_period_sweep(we_period_sweep),
        .i_period_sweep_pace(period_sweep_pace),
        .i_period_sweep_direction(period_sweep_direction),
        .i_period_sweep_step(period_sweep_step),
        .i_we_length_timer_duty_ratio(we_length_timer_duty_ratio),
        .i_duty_ratio(duty_ratio),
        .i_initial_timer(initial_timer),
        .i_we_volume_envelope(we_volume_envelope),
        .i_initial_volume(initial_volume),
        .i_volume_delta_direction(volume_delta_direction),
        .i_volume_sweep_pace(volume_sweep_pace),
        .i_we_period_low(we_period_low),
        .i_period_low(period_low),
        .i_we_period_high_control(we_period_high_control),
        .i_period_high(period_high),
        .i_length_timer_enable(length_timer_enable),
        .i_trigger(trigger),
        .o_enable(enable),
        .o_dac_enable(dac_enable),
        .o_signal(signal)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    // リセットタスク
    task automatic pg_reset;
        begin
            rst_n = 0;
            #STEP
            rst_n = 1;
            #STEP

            `ASSERT_EQ(pg.o_enable, 0);
            `ASSERT_EQ(pg.o_dac_enable, 0);
            `ASSERT_EQ(pg.clk_count, 1);
            `ASSERT_EQ(pg.clk_sample_update_period, 1);
            `ASSERT_EQ(pg.period, 0);
            `ASSERT_EQ(pg.period_update_enable, 0);
            `ASSERT_EQ(pg.period_sweep_direction, 0);
            `ASSERT_EQ(pg.period_sweep_step, 0);
            `ASSERT_EQ(pg.period_update_period, 0);
            `ASSERT_EQ(pg.period_update_count, 1);
            `ASSERT_EQ(pg.duty_ratio, 0);
            `ASSERT_EQ(pg.pulse_table_index, 0);
            `ASSERT_EQ(enable, 0);
            `ASSERT_EQ(dac_enable, 0);
        end
    endtask

    // スイープ設定タスク
    task automatic pg_set_period_sweep;
        input [2:0] i_period_sweep_pace;
        input i_period_sweep_direction;
        input [2:0] i_period_sweep_step;

        begin
            period_sweep_pace = i_period_sweep_pace;
            period_sweep_direction = i_period_sweep_direction;
            period_sweep_step = i_period_sweep_step;

            we_period_sweep = 1;
            #STEP
            we_period_sweep = 0;

            `ASSERT_EQ(pg.period_sweep_direction, i_period_sweep_direction);
            `ASSERT_EQ(pg.period_sweep_step, i_period_sweep_step);
            if (i_period_sweep_pace > 0) begin
                `ASSERT_EQ(pg.period_update_enable, 1);
                `ASSERT_TRUE(pg.period_update_period > 0);
            end else begin
                `ASSERT_EQ(pg.period_update_enable, 0);
                `ASSERT_EQ(pg.period_update_period, 0);
            end
        end
    endtask

    // 長さタイマー・デューティ比の設定タスク
    task automatic pg_set_length_timer_duty_ratio;
        input [5:0] i_initial_timer;
        input [1:0] i_duty_ratio;

        begin
            initial_timer = i_initial_timer;
            duty_ratio = i_duty_ratio;

            we_length_timer_duty_ratio = 1;
            #STEP
            we_length_timer_duty_ratio = 0;

            `ASSERT_EQ(pg.timer.initial_timer_count, {2'd0, i_initial_timer});
            `ASSERT_EQ(pg.duty_ratio, i_duty_ratio);
        end
    endtask

    // エンベロープジェネレータの設定タスク
    task automatic pg_set_volume_envelope;
        input [3:0] i_initial_volume;
        input i_volume_delta_direction;
        input [2:0] i_volume_sweep_pace;

        begin
            initial_volume = i_initial_volume;
            volume_delta_direction = i_volume_delta_direction;
            volume_sweep_pace = i_volume_sweep_pace;

            we_volume_envelope = 1;
            #STEP
            we_volume_envelope = 0;

            `ASSERT_EQ(pg.eg.initial_volume, i_initial_volume);
            `ASSERT_EQ(pg.eg.volume_delta_direction, i_volume_delta_direction);
            `ASSERT_EQ(pg.eg.volume_sweep_pace, i_volume_sweep_pace);
        end
    endtask
    
    // 更新周期下位ビットの設定タスク
    task automatic pg_set_period_low;
        input [7:0] i_period_low;

        begin
            period_low = i_period_low;

            we_period_low = 1;
            #STEP
            we_period_low = 0;

            `ASSERT_EQ(pg.period[7:0], i_period_low);
        end
    endtask

    // 更新周期上位ビット・制御フラグの設定タスク
    task automatic pg_set_period_high_control;
        input [2:0] i_period_high;
        input i_length_timer_enable;
        input i_trigger;

        begin
            period_high = i_period_high;
            length_timer_enable = i_length_timer_enable;
            trigger = i_trigger;

            we_period_high_control = 1;
            #STEP
            we_period_high_control = 0;

            `ASSERT_EQ(pg.period[10:8], i_period_high);
            `ASSERT_EQ(pg.timer.enable, i_length_timer_enable);
            `ASSERT_EQ(pg.trigger, i_trigger);
        end
    endtask

    // デューティ比の設定テスト
    task automatic pg_duty_ratio_test;
        integer i, d;

        begin
            pg_reset();
            pg_set_period_sweep(0, 0, 0);
            // 音量は固定で4'hF
            pg_set_volume_envelope(4'hF, 1, 0);

            for (d = 0; d < 4; d = d + 1) begin
                // デューティ比設定
                pg_set_length_timer_duty_ratio(0, d[1:0]); 
                // ピッチは7FF（1クロック更新）に設定
                pg_set_period_low(8'hFF);
                // トリガー
                pg_set_period_high_control(3'h7, 0, 1);
                // 念のため2周分
                for (i = 0; i < 16; i = i + 1) begin
                    #STEP
                    // トリガー直後でインデックスが1進んでいるため+1して比較
                    `EXPECT_EQ(pg.o_signal, pg.pulse_table(d[1:0], i[2:0] + 1) ? 4'hF : 0);
                    `EXPECT_EQ(signal, pg.pulse_table(d[1:0], i[2:0] + 1) ? 4'hF : 0);
                end
            end
        end
    endtask

    // 長さタイマーのテスト
    task automatic pg_timer_test;
        reg [15:0] last_clk_count;
        reg [3:0] last_signal;

        begin
            pg_reset();
            pg_set_period_sweep(0, 0, 0);
            pg_set_volume_envelope(4'hF, 1, 0);
            // タイマーをセットしてトリガー
            pg_set_length_timer_duty_ratio(6'h3F, 0); 
            pg_set_period_low(8'hFF);
            pg_set_period_high_control(3'h7, 1, 1);
            
            `ASSERT_EQ(pg.o_enable, 1);
            `ASSERT_EQ(pg.timer_expired, 0);
            
            // 時間切れまで待機
            @(posedge pg.timer_expired)
            
            // タイマーが時間切れした瞬間はまだ有効
            `EXPECT_EQ(pg.o_enable, 1);

            #(STEP/2)
            last_clk_count = pg.clk_count;
            last_signal = pg.o_signal;
            
            // 1クロック以降の状態を観測
            #(2 * STEP)
            
            // 無効になっており、最後の状態が保持されている
            `EXPECT_EQ(pg.o_enable, 0);
            `EXPECT_EQ(pg.clk_count, last_clk_count);
            `EXPECT_EQ(pg.o_signal, last_signal);
            `EXPECT_EQ(signal, last_signal);
        end
    endtask

    initial begin
        $dumpfile("build/test_pulse_generator.vcd");
        $dumpvars(0, test_pulse_generator);

        clk = 0;

        pg_duty_ratio_test();
        pg_timer_test();

        $finish;
    end
endmodule
