`include "test.vh"
`timescale 1ns/1ns

module test_length_timer;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg enable;
    reg we;
    reg trigger;
    reg [7:0] initial_length_timer;
    reg [15:0] timeout;
    wire expired;
    integer t, i;

    length_timer #(
        .CLOCK_HZ(256)
    ) timer(
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .trigger(trigger),
        .i_enable(enable),
        .i_initial_length_timer(initial_length_timer),
        .i_timeout(timeout),
        .o_expired(expired)
    );

    // タイマーのテストケース
    task automatic timer_test_case;
        input [7:0] test_initial_length_timer;
        input [15:0] test_timeout;
        input integer expected_clk_timeout;
    
        begin
            // リセット
            rst_n <= 0;
            #STEP
            rst_n <= 1;
            #STEP
            `ASSERT_EQ(timer.expired, 0);
            `ASSERT_EQ(timer.enable, 0);
            `ASSERT_EQ(timer.initial_length_timer, 8'd0);
            `ASSERT_EQ(timer.length_timer, 16'd0);
            `ASSERT_EQ(timer.timeout, 16'd0);
            `ASSERT_EQ(timer.clk_count, 16'd1);

            // パラメータセット
            enable <= 1;
            initial_length_timer <= test_initial_length_timer;
            timeout <= test_timeout;
            we <= 1;
            #STEP
            we <= 0;
            `ASSERT_EQ(timer.enable, 1);
            `ASSERT_EQ(timer.initial_length_timer, test_initial_length_timer);
            `ASSERT_EQ(timer.timeout, test_timeout);

            // トリガー
            `ASSERT_EQ(timer.expired, 0);
            trigger <= 1;
            #STEP
            trigger <= 0;

            // 期待した時間待機
            #(expected_clk_timeout * STEP)
            // 時間切れになっていることをチェック
            `EXPECT_EQ(timer.expired, 1);
            `EXPECT_EQ(expired, 1);
        end
    endtask

    always #(STEP/2) begin
        clk <= ~clk;
    end

    initial begin
        $dumpfile("build/test_length_timer.vcd");
        $dumpvars(0, test_length_timer);

        clk <= 0;

        // 初期タイマー値を0に固定し、期待した時間でexpiredが立つかチェック
        for (t = 0; t <= 10; t = t + 1) begin
            timer_test_case(8'd0, t, t);
        end

        // TODO
        for (t = 0; t <= 2; t = t + 1) begin
            for (i = 0; i < t; i = i + 1) begin
                timer_test_case(i, t, t - i + 1);
            end
        end

        $finish;
    end
endmodule
