`include "test.vh"
`timescale 1ns/1ns

module test_length_timer;
    parameter STEP = 10;
    localparam CLK_UPDATE_PERIOD = 4194304 / 256;

    reg clk;
    reg rst_n;
    reg tcycle_tick;
    reg enable;
    reg we_enable;
    reg we_length_timer;
    reg trigger;
    reg [7:0] initial_timer_count;
    reg [15:0] timeout;
    wire expired;
    integer t, i;

    length_timer timer (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_tcycle_tick(tcycle_tick),
        .i_we_enable(we_enable),
        .i_enable(enable),
        .i_we_length_timer(we_length_timer),
        .i_initial_timer_count(initial_timer_count),
        .i_timeout(timeout),
        .i_trigger(trigger),
        .o_expired(expired)
    );

    // タイマーのテストケース
    task automatic timer_test_case;
        input [7:0] test_initial_timer_count;
        input [15:0] test_timeout;
        input integer expected_clk_timeout;
    
        begin
            // リセット
            rst_n = 0;
            @(posedge clk);
            rst_n = 1;
            @(posedge clk); @(negedge clk);

            `ASSERT_EQ(timer.o_expired, 1);
            `ASSERT_EQ(timer.enable, 0);
            `ASSERT_EQ(timer.initial_timer_count, 8'd0);
            `ASSERT_EQ(timer.timer_count, 16'd1);
            `ASSERT_EQ(timer.timeout, 16'd0);
            `ASSERT_EQ(timer.clk_count, 16'd1);

            // パラメータセット
            initial_timer_count = test_initial_timer_count;
            timeout = test_timeout;
            we_length_timer = 1;
            @(posedge clk); @(negedge clk);
            we_length_timer = 0;
            `ASSERT_EQ(timer.initial_timer_count, test_initial_timer_count);
            `ASSERT_EQ(timer.timeout, test_timeout);

            enable = 1;
            we_enable = 1;
            @(posedge clk); @(negedge clk);
            we_enable = 0;
            `ASSERT_EQ(timer.enable, 1);

            // トリガー
            `ASSERT_EQ(timer.o_expired, 1);
            trigger = 1;
            @(posedge clk); @(negedge clk);
            trigger = 0;

            // 期待した時間待機
            repeat (expected_clk_timeout) @(posedge clk);
            @(negedge clk);
            // 時間切れになっていることをチェック
            `EXPECT_EQ(timer.o_expired, 1);
            `EXPECT_EQ(expired, 1);

            // 今一度同じ時間待機
            repeat (expected_clk_timeout) @(posedge clk);
            @(negedge clk);
            // 時間切れになっていることをチェック
            `EXPECT_EQ(timer.o_expired, 1);
            `EXPECT_EQ(expired, 1);
        end
    endtask

    always #(STEP/2) begin
        clk = ~clk;
    end

    initial begin
        $dumpfile("build/test_length_timer.vcd");
        $dumpvars(0, test_length_timer);

        tcycle_tick = 1;
        clk = 0;

        // 初期タイマー値を0に固定し、期待した時間でexpiredが立つかチェック
        for (t = 0; t <= 5; t = t + 1) begin
            timer_test_case(8'd0, t[15:0], CLK_UPDATE_PERIOD * (t + 1));
        end

        // 初期タイマー値を変えてチェック
        for (t = 0; t <= 5; t = t + 1) begin
            for (i = 0; i <= t; i = i + 1) begin
                timer_test_case(i[7:0], t[15:0], CLK_UPDATE_PERIOD * (t - i + 1));
            end
        end

        $finish;
    end
endmodule
