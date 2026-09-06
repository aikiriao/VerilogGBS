`include "test.vh"
`timescale 1ns/1ns

module test_sample_generator;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg we_dac_enable;
    reg we_length_timer;
    reg we_output_level;
    reg we_period_low;
    reg we_wave_ram;
    reg we_period_high_control;

    reg in_dac_enable;
    reg [5:0] initial_timer;
    reg [1:0] output_level;
    reg [7:0] period_low;
    reg [4:0] wave_even_index;
    reg [7:0] wave_2pcm;
    reg [2:0] period_high;
    reg length_timer_enable;
    reg trigger;

    wire [3:0] signal;
    wire enable;
    wire dac_enable;

    sample_generator #(
        .CLOCK_HZ(2097152)
    ) sg (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we_dac_enable(we_dac_enable),
        .i_dac_enable(in_dac_enable),
        .i_we_length_timer(we_length_timer),
        .i_initial_timer(initial_timer),
        .i_we_output_level(we_output_level),
        .i_output_level(output_level),
        .i_we_period_low(we_period_low),
        .i_period_low(period_low),
        .i_we_wave_ram(we_wave_ram),
        .i_wave_even_index(wave_even_index),
        .i_wave_2pcm(wave_2pcm),
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
    task automatic sg_reset;
        integer i;

        begin
            rst_n = 0;
            #STEP
            rst_n = 1;
            #STEP

            `ASSERT_EQ(sg.o_enable, 0);
            `ASSERT_EQ(sg.o_dac_enable, 0);
            `ASSERT_EQ(sg.clk_count, 1);
            `ASSERT_EQ(sg.clk_sample_update_period, 1);
            `ASSERT_EQ(sg.level_shift, 4);
            `ASSERT_EQ(sg.period, 0);
            `ASSERT_EQ(sg.period_changed, 0);
            for (i = 0; i < 32; i = i + 1) begin
                `ASSERT_EQ(sg.wave_ram[i], 0);
            end
            `ASSERT_EQ(sg.wave_ram_index, 0);
        end
    endtask

    // 長さタイマーの設定タスク
    task automatic sg_set_length_timer;
        input [5:0] i_initial_timer;

        begin
            initial_timer = i_initial_timer;

            we_length_timer = 1;
            #STEP
            we_length_timer = 0;

            `ASSERT_EQ(sg.timer.initial_timer_count, i_initial_timer);
        end
    endtask

    // DAC有効フラグの設定タスク
    task automatic sg_set_dac_enable;
        input i_dac_enable;

        begin
            in_dac_enable = i_dac_enable;

            we_dac_enable = 1;
            #STEP
            we_dac_enable = 0;

            `ASSERT_EQ(sg.o_dac_enable, i_dac_enable);
        end
    endtask

    // 出力レベルの設定タスク
    task automatic sg_set_output_level;
        input [1:0] i_output_level;

        begin
            output_level = i_output_level;

            we_output_level = 1;
            #STEP
            we_output_level = 0;

            `ASSERT_TRUE(sg.level_shift <= 4);
        end
    endtask
    
    // 更新周期下位ビットの設定タスク
    task automatic sg_set_period_low;
        input [7:0] i_period_low;

        begin
            period_low = i_period_low;

            we_period_low = 1;
            #STEP
            we_period_low = 0;

            `ASSERT_EQ(sg.period[7:0], i_period_low);
        end
    endtask

    // 波形RAM設定タスク
    task automatic sg_set_wave_ram;
        input [4:0] i_wave_even_index;
        input [7:0] i_wave_2pcm;

        begin
            wave_even_index = i_wave_even_index;
            wave_2pcm = i_wave_2pcm;

            we_wave_ram = 1;
            #STEP
            we_wave_ram = 0;

            `ASSERT_EQ(sg.wave_ram[i_wave_even_index + 0], i_wave_2pcm[7:4]);
            `ASSERT_EQ(sg.wave_ram[i_wave_even_index + 1], i_wave_2pcm[3:0]);
        end
    endtask

    // 更新周期上位ビット・制御フラグの設定タスク
    task automatic sg_set_period_high_control;
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

            `ASSERT_EQ(sg.period[10:8], i_period_high);
            `ASSERT_EQ(sg.timer.enable, i_length_timer_enable);
            `ASSERT_EQ(sg.trigger, i_trigger);
        end
    endtask

    // 定数をとる波形の再生テスト
    task automatic sg_constant_sample_test;
        input integer period;
        input integer period_count;
        integer i;

        begin
            // 0（常に無音）のケース
            sg_reset();
            sg_set_length_timer(0);
            sg_set_dac_enable(1);
            sg_set_output_level(1); // 最大音量（シフトなし）
            // 波形RAM全てに1をセット（シフトがあれば0になるので）
            for (i = 0; i < 16; i = i + 1) begin
                sg_set_wave_ram(2 * i, {4'h1, 4'h1});
            end
            // ピッチは7FF（最速）に設定
            sg_set_period_low(8'hFF);
            // トリガー
            sg_set_period_high_control(3'h7, 0, 1);

            for (i = 0; i < period_count; i = i + 1) begin
                #(period * STEP)
                `EXPECT_EQ(sg.o_signal, 1);
            end
        end
    endtask

    // レベル設定テスト
    task automatic sg_level_test;
        integer s, i, shift;

        begin
            for (s = 0; s < 4; s = s + 1) begin
                // シフト量
                case (s)
                    2'd0: shift = 4;
                    2'd1: shift = 0;
                    2'd2: shift = 1;
                    2'd3: shift = 2;
                endcase
                // 0（常に無音）のケース
                sg_reset();
                sg_set_length_timer(0);
                sg_set_dac_enable(1);
                sg_set_output_level(s);
                // 波形RAM全てにFをセット
                for (i = 0; i < 16; i = i + 1) begin
                    sg_set_wave_ram(2 * i, {4'hF, 4'hF});
                end
                // ピッチは7FF（最速）に設定
                sg_set_period_low(8'hFF);
                // トリガー
                sg_set_period_high_control(3'h7, 0, 1);
                // 意図したシフトがされているか？念のため2周
                for (i = 0; i < 64; i = i + 1) begin
                    #STEP
                    `EXPECT_EQ(sg.o_signal, 4'hF >> shift);
                end
            end
        end
    endtask

    // リニアフェード波形の再生テスト
    task automatic sg_linear_fade_test;
        input integer period;
        input integer period_count;
        integer i;
        reg [7:0] pcm2;

        begin
            // 0（常に無音）のケース
            sg_reset();
            sg_set_length_timer(0);
            sg_set_dac_enable(1);
            sg_set_output_level(1); // 最大音量（シフトなし）
            // 波形RAMにリニアフェード
            for (i = 0; i < 16; i = i + 1) begin
                pcm2[7:4] = i;
                pcm2[3:0] = i;
                sg_set_wave_ram(2 * i, pcm2);
            end
            // ピッチは7FF（最速）に設定
            sg_set_period_low(8'hFF);
            // トリガー
            sg_set_period_high_control(3'h7, 0, 1);

            for (i = 0; i < period_count; i = i + 1) begin
                #(period * STEP)
                `EXPECT_EQ(sg.o_signal, ((i >> 1) + 1) & 4'hF);
            end
        end
    endtask

    initial begin
        $dumpfile("build/test_sample_generator.vcd");
        $dumpvars(0, test_sample_generator);

        clk = 0;

        sg_constant_sample_test(1, 4 * 32);
        sg_linear_fade_test(1, 4 * 32);
        sg_level_test();

        $finish;
    end
endmodule
