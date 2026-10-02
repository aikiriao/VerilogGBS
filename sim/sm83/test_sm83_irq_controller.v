`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_sm83_irq_controller;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg we_register;
    reg [15:0] address;
    reg [7:0] w_data;
    wire [7:0] r_data;
    reg vblank_irq;
    reg lcd_irq;
    reg timer_irq;
    reg serial_irq;
    reg joypad_irq;
    reg [4:0] irq_ack;
    wire [4:0] irq_pending;

    sm83_irq_controller controller (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we_register(we_register),
        .i_address(address),
        .i_w_data(w_data),
        .i_vblank_irq(vblank_irq),
        .i_lcd_irq(lcd_irq),
        .i_timer_irq(timer_irq),
        .i_serial_irq(serial_irq),
        .i_joypad_irq(joypad_irq),
        .i_irq_ack(irq_ack),
        .o_r_data(r_data),
        .o_irq_pending(irq_pending)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    // リセットタスク
    task automatic sm83_irq_controller_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            `ASSERT_EQ(controller.if_reg, 0);
            `ASSERT_EQ(controller.ie_reg, 0);
        end
    endtask

    // レジスタ書き込み
    task automatic sm83_irq_controller_write_register;
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

    // 割り込みコントローラのテスト
    task automatic sm83_irq_controller_test;
        integer i;
        begin
            for (i = 0; i < 5; i = i + 1) begin
                sm83_irq_controller_reset();
                sm83_irq_controller_write_register(`HWREG_IE_INTERRUPT_ENABLE, 8'b00011111);
                address = `HWREG_IF_INTERRUPT_FLAG;

                vblank_irq = 0;
                lcd_irq = 0;
                timer_irq = 0;
                serial_irq = 0;
                joypad_irq = 0;

                // 割り込み要求信号を入力
                case (i) 
                    0: vblank_irq = 1;
                    1: lcd_irq = 1;
                    2: timer_irq = 1;
                    3: serial_irq = 1;
                    4: joypad_irq = 1;
                endcase
                @(posedge clk); @(negedge clk);
                `EXPECT_EQ(controller.if_reg, (1 << i));
                `EXPECT_EQ(irq_pending, (1 << i));
                `EXPECT_EQ(r_data, (1 << i));

                // 割り込み要求信号を落としてもフラグは残る
                case (i) 
                    0: vblank_irq = 0;
                    1: lcd_irq = 0;
                    2: timer_irq = 0;
                    3: serial_irq = 0;
                    4: joypad_irq = 0;
                endcase
                @(posedge clk); @(negedge clk);
                `EXPECT_EQ(controller.if_reg, (1 << i));
                `EXPECT_EQ(irq_pending, (1 << i));
                `EXPECT_EQ(r_data, (1 << i));

                // ACKを入力することでフラグが落ちる
                irq_ack = (1 << i);
                @(posedge clk); @(negedge clk);
                `EXPECT_EQ(controller.if_reg, 5'b00000);
                `EXPECT_EQ(irq_pending, 5'b00000);
                `EXPECT_EQ(r_data, 8'b00000000);

                // 割り込み信号とACKが同時に来たときは割り込み要求が残る
                case (i) 
                    0: vblank_irq = 1;
                    1: lcd_irq = 1;
                    2: timer_irq = 1;
                    3: serial_irq = 1;
                    4: joypad_irq = 1;
                endcase
                irq_ack = (1 << i);
                @(posedge clk); @(negedge clk);
                `EXPECT_EQ(controller.if_reg, (1 << i));
                `EXPECT_EQ(irq_pending, (1 << i));
                `EXPECT_EQ(r_data, (1 << i));
            end
        end
    endtask

    initial begin
        $dumpfile("build/test_sm83_irq_controller.vcd");
        $dumpvars(0, test_sm83_irq_controller);

        clk = 0;
            
        sm83_irq_controller_test();

        $finish;
    end
    
endmodule
