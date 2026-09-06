`include "test.vh"
`timescale 1ns/1ns

module test_noise_generator;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg we_length_timer;
    reg we_volume_envelope;
    reg we_frequency_randomness;
    reg we_control;

    reg [5:0] initial_timer;
    reg [3:0] initial_volume;
    reg volume_delta_dir;
    reg [2:0] volume_sweep_pace;
    reg [3:0] clock_shift;
    reg lfsr_mode;
    reg [2:0] clock_divider;
    reg length_timer_enable;
    reg trigger;

    wire [3:0] signal;
    wire enable;
    wire dac_enable;

    noise_generator #(
        .CLOCK_HZ(65536) // 実際の動作クロックより遅くする（エンベロープジェネレータなどの動作を早めるため）
    ) ng (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we_length_timer(we_length_timer),
        .i_initial_timer(initial_timer),
        .i_we_volume_envelope(we_volume_envelope),
        .i_initial_volume(initial_volume),
        .i_volume_delta_dir(volume_delta_dir),
        .i_volume_sweep_pace(volume_sweep_pace),
        .i_we_frequency_randomness(we_frequency_randomness),
        .i_clock_shift(clock_shift),
        .i_lfsr_mode(lfsr_mode),
        .i_clock_divider(clock_divider),
        .i_we_control(we_control),
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
    task automatic ng_reset;
        begin
            rst_n = 0;
            #STEP
            rst_n = 1;
            #STEP

            `ASSERT_EQ(ng.o_enable, 0);
            `ASSERT_EQ(ng.o_dac_enable, 0);
            `ASSERT_EQ(ng.clk_count, 1);
            `ASSERT_EQ(ng.clk_div_count, 1);
            `ASSERT_EQ(ng.clk_div_period, 0);
            `ASSERT_EQ(ng.lfsr_mask, 0);
            `ASSERT_EQ(ng.lfsr, 0);
        end
    endtask

    // 長さタイマーの設定タスク
    task automatic ng_set_length_timer;
        input [5:0] i_initial_timer;

        begin
            initial_timer = i_initial_timer;

            we_length_timer = 1;
            #STEP
            we_length_timer = 0;

            `ASSERT_EQ(ng.timer.initial_timer_count, i_initial_timer);
        end
    endtask

    // エンベロープジェネレータの設定タスク
    task automatic ng_set_volume_envelope;
        input [3:0] i_initial_volume;
        input i_volume_delta_dir;
        input [2:0] i_volume_sweep_pace;

        begin
            initial_volume = i_initial_volume;
            volume_delta_dir = i_volume_delta_dir;
            volume_sweep_pace = i_volume_sweep_pace;

            we_volume_envelope = 1;
            #STEP
            we_volume_envelope = 0;

            `ASSERT_EQ(ng.eg.initial_volume, i_initial_volume);
            `ASSERT_EQ(ng.eg.volume_delta_dir, i_volume_delta_dir);
            `ASSERT_EQ(ng.eg.volume_sweep_pace, i_volume_sweep_pace);
        end
    endtask

    // 更新頻度・ランダムネスの設定タスク
    task automatic ng_set_frequency_randomness;
        input [3:0] i_clock_shift;
        input i_lfsr_mode;
        input [2:0] i_clock_divider;

        begin
            clock_shift = i_clock_shift;
            lfsr_mode = i_lfsr_mode;
            clock_divider = i_clock_divider;

            we_frequency_randomness = 1;
            #STEP
            we_frequency_randomness = 0;

            `ASSERT_NEQ(ng.lfsr_mask, 0);
        end
    endtask

    // 制御フラグ設定タスク
    task automatic ng_set_control;
        input i_length_timer_enable;
        input i_trigger;

        begin
            length_timer_enable = i_length_timer_enable;
            trigger = i_trigger;

            we_control = 1;
            #STEP
            we_control = 0;

            if (i_trigger) begin
                `ASSERT_EQ(ng.o_enable, 1);
                `ASSERT_EQ(ng.clk_count, 1);
                `ASSERT_EQ(ng.clk_div_count, 1);
                `ASSERT_EQ(ng.lfsr, 0);
            end
        end
    endtask

    // トリガーを打たなかったときのテスト
    task automatic ng_nontrigger_test;
        begin
            ng_reset();
            ng_set_volume_envelope(0, 0, 0);
            ng_set_frequency_randomness(0, 0, 0);
            ng_set_length_timer(0);
            // トリガーしない
            ng_set_control(0, 0);
            
            #STEP

            `EXPECT_EQ(ng.o_enable, 0);
            `EXPECT_EQ(ng.clk_count, 1);
            `EXPECT_EQ(ng.clk_div_count, 1);
            `EXPECT_EQ(ng.lfsr, 0);
        end
    endtask

    // DAC無効化したときのテスト
    task automatic ng_dac_disable_test;
        begin
            ng_reset();
            ng_set_frequency_randomness(0, 0, 0);
            ng_set_length_timer(0);
            ng_set_volume_envelope(0, 0, 0);
            
            `EXPECT_EQ(ng.o_dac_enable, 0);
            `EXPECT_EQ(ng.o_enable, 0);

            ng_set_volume_envelope(0, 1, 0);

            `EXPECT_EQ(ng.o_dac_enable, 1);
            `EXPECT_EQ(ng.o_enable, 0);
        end
    endtask

    // 0 or 定数をとるノイズのテスト
    task automatic ng_constant_noise_test;
        input integer period;
        input integer period_count;
        integer t;

        begin
            // 0（常に無音）のケース
            ng_reset();
            ng_set_volume_envelope(0, 1, 0);
            ng_set_frequency_randomness(0, 0, 0);
            // 維持時間タイマーは使わずにトリガー
            ng_set_length_timer(0);
            ng_set_control(0, 1);
            
            for (t = 0; t < period_count; t = t + 1) begin
                #(period * STEP)
                `EXPECT_EQ(signal, 0);
                `EXPECT_NEQ(ng.lfsr, 0);
            end

            // 最大振幅のケース
            ng_reset();
            ng_set_volume_envelope(4'hF, 1, 0);
            ng_set_frequency_randomness(0, 0, 0);
            ng_set_length_timer(0);
            ng_set_control(0, 1);
            
            for (t = 0; t < period_count; t = t + 1) begin
                #(period * STEP)
                if (signal != 0) begin
                    `EXPECT_EQ(signal, 4'hF);
                    `EXPECT_NEQ(ng.lfsr, 0);
                end
            end
        end
    endtask

    // フェードするノイズのテスト
    task automatic ng_fade_noise_test;
        input integer period;
        input integer period_count;
        integer t, volume;

        begin
            // 0から最大まで上がるケース
            ng_reset();
            ng_set_volume_envelope(4'h0, 1, 1);
            ng_set_frequency_randomness(0, 0, 0);
            // 維持時間タイマーは使わずにトリガー
            ng_set_length_timer(0);
            ng_set_control(0, 1);
            
            // 非減少を期待
            volume = 0;
            for (t = 0; t < period_count; t = t + 1) begin
                #(period * STEP)
                `EXPECT_TRUE(volume <= ng.eg_volume);
                volume = ng.eg_volume;
                `EXPECT_TRUE((signal === 0) || (signal === ng.eg_volume));
            end
            `EXPECT_EQ(ng.eg_volume, 4'hF);

            // 最大から0まで下がるケース
            ng_reset();
            ng_set_volume_envelope(4'hF, 0, 1);
            ng_set_frequency_randomness(0, 0, 0);
            ng_set_length_timer(0);
            ng_set_control(0, 1);
            
            // 非増加を期待
            volume = 4'hF;
            for (t = 0; t < period_count; t = t + 1) begin
                #(period * STEP)
                `EXPECT_TRUE(volume >= ng.eg_volume);
                volume = ng.eg_volume;
                `EXPECT_TRUE((signal === 0) || (signal === ng.eg_volume));
            end
            `EXPECT_EQ(ng.eg_volume, 4'h0);
        end
    endtask

    // 長さタイマーのテスト
    task automatic ng_timer_test;
        integer last_lfsr, last_clk_count, last_clk_div_count;

        begin
            ng_reset();
            ng_set_volume_envelope(4'hF, 1, 0);
            ng_set_frequency_randomness(0, 0, 0);
            // タイマーをセットしてトリガー
            ng_set_length_timer(1);
            ng_set_control(1, 1);
            
            `ASSERT_EQ(ng.o_enable, 1);
            `ASSERT_EQ(ng.timer_expired, 0);
            
            // 時間切れまで待機
            @(posedge ng.timer_expired)
            
            // タイマーが時間切れした瞬間はまだ有効
            `EXPECT_EQ(ng.o_enable, 1);
            last_lfsr = ng.lfsr;
            last_clk_count = ng.clk_count;
            last_clk_div_count = ng.clk_div_count;
            
            // 1クロック以降の状態を観測
            #(2 * STEP)
            
            // 無効になっており、最後の状態が保持されている
            `EXPECT_EQ(ng.o_enable, 0);
            `EXPECT_EQ(ng.lfsr, last_lfsr);
            `EXPECT_EQ(ng.clk_count, last_clk_count);
            `EXPECT_EQ(ng.clk_div_count, last_clk_div_count);
        end
    endtask

    initial begin
        $dumpfile("build/test_noise_generator.vcd");
        $dumpvars(0, test_noise_generator);

        clk = 0;

        ng_nontrigger_test();
        ng_dac_disable_test();
        ng_constant_noise_test(1000, 20);
        ng_fade_noise_test(1000, 20);
        ng_timer_test();

        $finish;
    end
endmodule
