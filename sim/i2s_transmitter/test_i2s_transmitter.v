`include "test.vh"
`timescale 1ns/1ns

module test_i2s_transmitter;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg [15:0] l_data;
    reg [15:0] r_data;
    wire req;
    wire bck;
    wire ws;
    wire sd;

    reg [23:0] l_data24;
    reg [23:0] r_data24;
    wire req24;
    wire bck24;
    wire ws24;
    wire sd24;

    i2s_transmitter i2s_tx (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_l_data(l_data),
        .i_r_data(r_data),
        .o_req(req),
        .o_bck(bck),
        .o_ws(ws),
        .o_sd(sd)
    );

    i2s_transmitter #(
        .BITS_PER_SAMPLE(24)
    ) i2s_tx24 (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_l_data(l_data24),
        .i_r_data(r_data24),
        .o_req(req24),
        .o_bck(bck24),
        .o_ws(ws24),
        .o_sd(sd24)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    // 8bitの乱数生成
    /* verilator lint_off UNUSEDSIGNAL */
    task automatic random8;
        output reg [7:0] r8;
        reg [31:0] r;
        begin
            r = $random;
            r8 = r[7:0];
        end
    endtask
    /* verilator lint_on UNUSEDSIGNAL */

    // 16bitの乱数生成
    task automatic random16;
        output reg [15:0] r16;
        begin
            random8(r16[15:8]);
            random8(r16[7:0]);
        end
    endtask

    // 24bitの乱数生成
    task automatic random24;
        output reg [23:0] r24;
        begin
            random8(r24[23:16]);
            random8(r24[15:8]);
            random8(r24[7:0]);
        end
    endtask

    // リセットタスク
    task automatic i2s_transmitter_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            `ASSERT_EQ(i2s_tx.b_cnt, 0);
            `ASSERT_EQ(i2s_tx.o_req, 0);
            `ASSERT_EQ(i2s_tx.req_d1, 0);
            `ASSERT_EQ(i2s_tx.l_data_buffer, 0);
            `ASSERT_EQ(i2s_tx.r_data_buffer, 0);
            `ASSERT_EQ(i2s_tx.o_ws, 0);
            `ASSERT_EQ(i2s_tx.o_sd, 0);

            `ASSERT_EQ(i2s_tx24.b_cnt, 0);
            `ASSERT_EQ(i2s_tx24.o_req, 0);
            `ASSERT_EQ(i2s_tx24.req_d1, 0);
            `ASSERT_EQ(i2s_tx24.l_data_buffer, 0);
            `ASSERT_EQ(i2s_tx24.r_data_buffer, 0);
            `ASSERT_EQ(i2s_tx24.o_ws, 0);
            `ASSERT_EQ(i2s_tx24.o_sd, 0);
        end
    endtask

    // 16bitデータ送信テスト
    task automatic i2s_transmitter_transmit16_test;
        integer clk_count;
        reg [15:0] prev_l_data;
        reg [15:0] prev_r_data;
        reg [31:0] sd_buffer;
        reg prev_ws;
        begin
            i2s_transmitter_reset();
            l_data = 16'd0;
            r_data = 16'd0;
            prev_ws = 0;
            for (clk_count = 0; clk_count < 16 * 10; clk_count = clk_count + 1) begin
                @(negedge bck);
                // （送信側）データ要求があればデータをセット
                if (req) begin
                    prev_l_data = l_data;
                    prev_r_data = r_data;
                    random16(l_data);
                    random16(r_data);
                end
                // （受信側）出力シリアルデータの受信
                sd_buffer = {sd_buffer[30:0], sd};
                // 左チャンネルに戻ったところで受信データチェック
                prev_ws = ws;
                if ((prev_ws == 1) && (ws == 0)) begin
                    `EXPECT_EQ(prev_l_data, sd_buffer[31:16]);
                    `EXPECT_EQ(prev_r_data, sd_buffer[15:0]);
                end
                @(posedge bck);
            end
        end
    endtask

    // 24bitデータ送信テスト
    task automatic i2s_transmitter_transmit24_test;
        integer clk_count;
        reg [23:0] prev_l_data;
        reg [23:0] prev_r_data;
        reg [47:0] sd_buffer;
        reg prev_ws;
        begin
            i2s_transmitter_reset();
            l_data24 = 24'd0;
            r_data24 = 24'd0;
            prev_ws = 0;
            for (clk_count = 0; clk_count < 24 * 10; clk_count = clk_count + 1) begin
                @(negedge bck24);
                // （送信側）データ要求があればデータをセット
                if (req24) begin
                    prev_l_data = l_data24;
                    prev_r_data = r_data24;
                    random24(l_data24);
                    random24(r_data24);
                end
                // （受信側）出力シリアルデータの受信
                sd_buffer = {sd_buffer[46:0], sd24};
                // 左チャンネルに戻ったところで受信データチェック
                prev_ws = ws24;
                if ((prev_ws == 1) && (ws24 == 0)) begin
                    `EXPECT_EQ(prev_l_data, sd_buffer[47:24]);
                    `EXPECT_EQ(prev_r_data, sd_buffer[23:0]);
                end
                @(posedge bck24);
            end
        end
    endtask

    initial begin
        $dumpfile("build/test_i2s_transmitter.vcd");
        $dumpvars(0, test_i2s_transmitter);

        clk = 0;

        i2s_transmitter_reset();
        i2s_transmitter_transmit16_test();
        i2s_transmitter_transmit24_test();

        $finish;
    end
endmodule
