`timescale 1ns/1ns
`include "sm83_register_address.vh"

module gbs_player #(
    parameter CLOCK_HZ = 1048576, // クロック動作周波数
    parameter SIGNAL_BIT_WIDTH = 16 // 出力信号のビット深度
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    output wire signed [SIGNAL_BIT_WIDTH-1:0] o_l_signal, // 左チャンネル信号
    output wire signed [SIGNAL_BIT_WIDTH-1:0] o_r_signal // 右チャンネル信号
);

    wire [15:0] address;
    wire [7:0] cpu_r_data;
    wire [7:0] cpu_w_data;
    wire [4:0] cpu_irq_pending;
    wire [4:0] cpu_irq_ack;
    wire cpu_we;
    wire cpu_re;
    wire apu_address = (address >= `HWREG_NR10_CHANNEL1_SWEEP) & (address < `HWREG_CHANNEL3_WAVE_PATTERN_RAM_END);
    wire apu_we = cpu_we & apu_address;
    wire [7:0] apu_r_data;
    wire timer_address = (address >= `HWREG_DIV_REGISTER) & (address <= `HWREG_TAC_TIMER_CONTROL);
    wire timer_we = cpu_we & timer_address;
    wire [7:0] timer_r_data;
    wire timer_irq;
    wire vblank_irq;
    wire irq_address = (address == `HWREG_IF_INTERRUPT_FLAG) | (address == `HWREG_IE_INTERRUPT_ENABLE);
    wire irq_we = cpu_we & irq_address;
    wire [7:0] irq_r_data;
    wire [7:0] memory_r_data;
    wire memory_address = (address < `HWREG_START_ADDRESS) | ((address >= `HRAM_START_ADDRESS) & (address < `HWREG_IE_INTERRUPT_ENABLE));
    wire memory_we = cpu_we & memory_address;

    // CPUへの入力データをアドレスに依存して決定
    assign cpu_r_data = (apu_address) ? apu_r_data
                        : (timer_address) ? timer_r_data
                        : (irq_address) ? irq_r_data
                        : (memory_address) ? memory_r_data
                        : 8'd0;

    // CPUコア
    sm83 cpu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_r_data(cpu_r_data), 
        .i_irq_pending(cpu_irq_pending), 
        .o_address(address),
        .o_w_data(cpu_w_data),
        .o_re(cpu_re),
        .o_we(cpu_we),
        .o_irq_ack(cpu_irq_ack)
    );

    // APU
    apu #(
        .SIGNAL_BIT_WIDTH(SIGNAL_BIT_WIDTH)
    ) apu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_register(apu_we),
        .i_address(address),
        .i_w_data(cpu_w_data),
        .o_r_data(apu_r_data),
        .o_l_signal(o_l_signal),
        .o_r_signal(o_r_signal)
    );

    // タイマー
    sm83_timer timer (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_register(timer_we),
        .i_address(address),
        .i_w_data(cpu_w_data),
        .o_r_data(timer_r_data),
        .o_timer_irq(timer_irq),
        .o_vblank_irq(vblank_irq)
    );

    // 割り込みコントローラ
    sm83_irq_controller irq_controller (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_register(irq_we),
        .i_address(address),
        .i_w_data(cpu_w_data),
        .i_vblank_irq(vblank_irq),
        .i_lcd_irq(1'b0), // 未使用
        .i_timer_irq(timer_irq),
        .i_serial_irq(1'b0), // 未使用
        .i_joypad_irq(1'b0), // 未使用
        .i_irq_ack(cpu_irq_ack),
        .o_r_data(irq_r_data),
        .o_irq_pending(cpu_irq_pending)
    );

    // メモリ
    sm83_gbs_memory memory (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_address(address),
        .i_w_data(cpu_w_data),
        .i_re(cpu_re),
        .i_we(memory_we),
        .o_r_data(memory_r_data)
    );

endmodule;
