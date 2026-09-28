`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_sm83_timer;
    parameter STEP = 10;
    parameter TIMER_CLOCK_HZ = 1048576;

    reg clk;
    reg rst_n;
    reg we_register;
    reg [15:0] address;
    reg [7:0] w_data;
    wire [7:0] r_data;
    wire timer_irq;
    wire vblank_irq;

    sm83_timer #(
        .CLOCK_HZ(TIMER_CLOCK_HZ)
    ) timer (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we_register(we_register),
        .i_address(address),
        .i_w_data(w_data),
        .o_r_data(r_data),
        .o_timer_irq(timer_irq),
        .o_vblank_irq(vblank_irq)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    // レジスタ書き込み
    task automatic sm83_timer_write_register;
        input [15:0] i_address;
        input [7:0] i_value;

        begin
            address = i_address;
            w_data = i_value;
            we_register = 1;
            @(posedge clk); @(negedge clk);
            we_register = 0;
        end
    endtask

    // リセットタスク
    task automatic sm83_timer_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            `ASSERT_EQ(timer.div_register, 0);
            `ASSERT_EQ(timer.tima_timer_counter, 0);
            `ASSERT_EQ(timer.tma_timer_modulo, 0);
            `ASSERT_EQ(timer.tac_timer_control, 0);
            `ASSERT_EQ(timer.div_clock_count, 0);
            `ASSERT_EQ(timer.timer_enable, 0);
            `ASSERT_EQ(timer.timer_increment_cycle, 256);
            `ASSERT_EQ(timer.timer_clock_count, 0);
            `ASSERT_EQ(timer.timer_count, 0);
            `ASSERT_EQ(timer_irq, 0);
            `ASSERT_EQ(vblank_irq, 0);
        end
    endtask

    // DIVタイマーテスト
    task automatic sm83_div_timer_test;
        integer t;
        begin
            sm83_timer_reset();
            // 何を書き込んでも0になる
            sm83_timer_write_register(`HWREG_DIV_REGISTER, 8'h00);
            address = `HWREG_DIV_REGISTER;
            `EXPECT_EQ(r_data, 0);
            sm83_timer_write_register(`HWREG_DIV_REGISTER, 8'h55);
            address = `HWREG_DIV_REGISTER;
            `EXPECT_EQ(r_data, 0);
            sm83_timer_write_register(`HWREG_DIV_REGISTER, 8'hAA);
            address = `HWREG_DIV_REGISTER;
            `EXPECT_EQ(r_data, 0);
            sm83_timer_write_register(`HWREG_DIV_REGISTER, 8'hFF);
            address = `HWREG_DIV_REGISTER;
            `EXPECT_EQ(r_data, 0);

            // タイマー値の更新チェック
            sm83_timer_reset();
            for (t = 0; t < 10; t = t + 1) begin
                repeat (64) @(posedge clk);
                @(negedge clk);

                address = `HWREG_DIV_REGISTER;
                `EXPECT_EQ(r_data, t[7:0]);
                `EXPECT_EQ(timer.div_register, t[7:0]);
            end
        end
    endtask

    initial begin
        $dumpfile("build/test_sm83_timer.vcd");
        $dumpvars(0, test_sm83_timer);

        clk = 0;

        sm83_timer_reset();
        sm83_div_timer_test();

        $finish;
    end
    
endmodule
