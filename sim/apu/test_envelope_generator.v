`include "test.vh"
`timescale 1ns/1ns

module test_envelope_generator;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg enable;
    reg we;
    reg trigger;
    reg volume_delta_dir;
    reg [3:0] initial_volume;
    reg [2:0] volume_sweep_pace;
    wire [3:0] volume;
    integer t, i;

    envelope_generator #(
        .CLOCK_HZ(64)
    ) eg (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we(we),
        .i_volume_delta_dir(volume_delta_dir),
        .i_initial_volume(initial_volume),
        .i_volume_sweep_pace(volume_sweep_pace),
        .i_trigger(trigger),
        .o_volume(volume)
    );

    // タイマーのテストケース
    task automatic eg_test_case;
        input [3:0] test_initial_volume;
        input test_volume_delta_dir;
        input [2:0] test_volume_sweep_pace;
        input integer wait_duration;
        input [3:0] expected_volume;
    
        begin
            // リセット
            rst_n <= 0;
            #STEP
            rst_n <= 1;
            #STEP
            `ASSERT_EQ(eg.o_volume, 0);
            `ASSERT_EQ(eg.initial_volume, 4'd0);
            `ASSERT_EQ(eg.volume_delta_dir, 0);
            `ASSERT_EQ(eg.volume_sweep_pace, 3'd0);
            `ASSERT_EQ(eg.timer_count, 3'd1);

            // パラメータセット
            initial_volume <= test_initial_volume;
            volume_delta_dir <= test_volume_delta_dir;
            volume_sweep_pace <= test_volume_sweep_pace;
            we <= 1;
            #STEP
            we <= 0;
            `ASSERT_EQ(eg.initial_volume, test_initial_volume);
            `ASSERT_EQ(eg.volume_delta_dir, volume_delta_dir);
            `ASSERT_EQ(eg.volume_sweep_pace, volume_sweep_pace);

            // トリガー
            `ASSERT_EQ(eg.o_volume, 0);
            trigger <= 1;
            #STEP
            trigger <= 0;

            // 期待した時間待機
            #(wait_duration * STEP)
            // 時間切れになっていることをチェック
            `EXPECT_EQ(eg.o_volume, expected_volume);
        end
    endtask

    always #(STEP/2) begin
        clk <= ~clk;
    end

    initial begin
        $dumpfile("build/test_envelope_generator.vcd");
        $dumpvars(0, test_envelope_generator);

        clk <= 0;

        // 単純な下降・上昇ケース
        eg_test_case(4'h0, 1, 1, 20, 4'hF);
        eg_test_case(4'hF, 0, 1, 20, 4'h0);

        $finish;
    end
endmodule
