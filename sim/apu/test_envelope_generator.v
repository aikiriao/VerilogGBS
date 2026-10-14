`include "test.vh"
`timescale 1ns/1ns

module test_envelope_generator;
    parameter STEP = 10;
    localparam CLK_UPDATE_PERIOD = 4194304 / 64;

    reg clk;
    reg rst_n;
    reg we;
    reg trigger;
    reg volume_delta_direction;
    reg tcycle_tick;
    reg [3:0] initial_volume;
    reg [2:0] volume_sweep_pace;
    wire [3:0] volume;
    integer i;

    envelope_generator eg (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_tcycle_tick(tcycle_tick),
        .i_we(we),
        .i_volume_delta_direction(volume_delta_direction),
        .i_initial_volume(initial_volume),
        .i_volume_sweep_pace(volume_sweep_pace),
        .i_trigger(trigger),
        .o_volume(volume)
    );

    // タイマーのテストケース
    task automatic eg_test_case;
        input [3:0] test_initial_volume;
        input test_volume_delta_direction;
        input [2:0] test_volume_sweep_pace;
        input integer wait_duration;
        input [3:0] expected_volume;
    
        begin
            // リセット
            rst_n = 0;
            #STEP
            rst_n = 1;
            #STEP
            `ASSERT_EQ(eg.o_volume, 0);
            `ASSERT_EQ(eg.initial_volume, 4'd0);
            `ASSERT_EQ(eg.volume_delta_direction, 0);
            `ASSERT_EQ(eg.volume_sweep_pace, 3'd0);
            `ASSERT_EQ(eg.timer_count, 3'd1);

            // パラメータセット
            initial_volume = test_initial_volume;
            volume_delta_direction = test_volume_delta_direction;
            volume_sweep_pace = test_volume_sweep_pace;
            we = 1;
            #STEP
            we = 0;
            `ASSERT_EQ(eg.initial_volume, test_initial_volume);
            `ASSERT_EQ(eg.volume_delta_direction, test_volume_delta_direction);
            `ASSERT_EQ(eg.volume_sweep_pace, test_volume_sweep_pace);

            // トリガー
            `ASSERT_EQ(eg.o_volume, 0);
            trigger = 1;
            #STEP
            trigger = 0;

            // 期待したクロックだけ待機
            repeat (CLK_UPDATE_PERIOD * wait_duration) @(posedge clk);
            // 信号値が確定するのを待つ
            @(negedge clk);

            // 期待したボリュームになっているかチェック
            `EXPECT_EQ(eg.o_volume, expected_volume);
            `EXPECT_EQ(volume, expected_volume);
        end
    endtask

    always #(STEP/2) begin
        clk = ~clk;
    end

    initial begin
        $dumpfile("build/test_envelope_generator.vcd");
        $dumpvars(0, test_envelope_generator);

        tcycle_tick = 1;
        clk = 0;

        // 即時設定ケース
        for (i = 0; i <= 4'hF; i = i + 1) begin
            eg_test_case(i[3:0], 1, 0, 1, i[3:0]);
            eg_test_case(i[3:0], 0, 0, 1, i[3:0]);
        end

        // 単純な下降・上昇ケース
        eg_test_case(4'h0, 1, 1, 16, 4'hF);
        eg_test_case(4'hF, 0, 1, 16, 4'h0);

        // ペースを変えたときのケース
        eg_test_case(4'h0, 1, 2, 16, 4'h8);
        eg_test_case(4'h0, 1, 4, 16, 4'h4);
        eg_test_case(4'hF, 0, 2, 16, 4'h7);
        eg_test_case(4'hF, 0, 4, 16, 4'hB);

        // ボリューム端点のケース
        eg_test_case(4'hF, 1, 1, 16, 4'hF);
        eg_test_case(4'h0, 0, 1, 16, 4'h0);

        $finish;
    end
endmodule
