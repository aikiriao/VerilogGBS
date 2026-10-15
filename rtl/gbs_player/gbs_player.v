`timescale 1ns/1ns
`include "sm83_register_address.vh"

module gbs_player #(
    parameter ROM_FILE = "", // 初期ROMファイル
    parameter ROM_ADDRESS_BITS = 22, // ROMアドレスビット幅
    parameter [24:0] CLOCK_HZ = 4194304, // クロック動作周波数
    parameter SIGNAL_BIT_WIDTH = 16 // 出力信号のビット深度
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    output wire signed [SIGNAL_BIT_WIDTH-1:0] o_l_signal, // 左チャンネル信号
    output wire signed [SIGNAL_BIT_WIDTH-1:0] o_r_signal // 右チャンネル信号
);

    localparam [24:0] TCYCLE_CLOCK_HZ = 4194304; // T-cycle周波数(Hz)
    localparam [24:0] WRAP_CLK_COUNT = CLOCK_HZ - TCYCLE_CLOCK_HZ; // クロックカウントが回り込んだ時の更新値

    reg [24:0] tcycle_clk_count;
    reg tcycle_tick; // T-Cycleのクロックティック
    reg mcycle_tick; // M-Cycleのクロックティック
    reg [1:0] tcycle_clk_div; // T-Cycleの1/4分周

    wire [15:0] address;
    wire [7:0] cpu_r_data;
    wire [7:0] cpu_w_data;
    wire [4:0] cpu_irq_pending;
    wire [4:0] cpu_irq_ack;
    wire cpu_we;
    wire cpu_re;
    wire cpu_we_pulse = cpu_we & mcycle_tick;
    wire apu_address = ((address >= `HWREG_NR10_CHANNEL1_SWEEP) && (address <= `HWREG_NR34_CHANNEL3_PERIOD_HIGH_CONTROL))
                    || ((address >= `HWREG_NR41_CHANNEL4_LENGTH_TIMER) && (address <= `HWREG_NR52_AUDIO_MASTER_CONTROL))
                    || ((address >= `HWREG_CHANNEL3_WAVE_PATTERN_RAM_START) && (address <= `HWREG_CHANNEL3_WAVE_PATTERN_RAM_END));
    wire apu_we = cpu_we_pulse & apu_address;
    wire [7:0] apu_r_data;
    wire timer_address = (address >= `HWREG_DIV_REGISTER) && (address <= `HWREG_TAC_TIMER_CONTROL);
    wire timer_we = cpu_we_pulse & timer_address;
    wire [7:0] timer_r_data;
    wire timer_irq;
    wire vblank_irq;
    wire irq_address = (address == `HWREG_IF_INTERRUPT_FLAG) || (address == `HWREG_IE_INTERRUPT_ENABLE);
    wire irq_we = cpu_we_pulse & irq_address;
    wire [7:0] irq_r_data;
    wire [7:0] memory_r_data;
    wire memory_address = (address < `HWREG_START_ADDRESS) || ((address >= `HRAM_START_ADDRESS) && (address < `HWREG_IE_INTERRUPT_ENABLE));
    wire memory_we = cpu_we_pulse & memory_address;

    // CPUへの入力データをアドレスに依存して決定
    assign cpu_r_data = (apu_address) ? apu_r_data
                        : (timer_address) ? timer_r_data
                        : (irq_address) ? irq_r_data
                        : (memory_address) ? memory_r_data
                        : 8'd0;

    // T-Cycleのクロックティックパルス生成
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tcycle_clk_count <= 25'd0;
            tcycle_tick <= 0;
        end else begin
            tcycle_tick <= 0;
            if ((tcycle_clk_count + TCYCLE_CLOCK_HZ) >= CLOCK_HZ) begin
                tcycle_tick <= 1;
                tcycle_clk_count <= tcycle_clk_count - WRAP_CLK_COUNT;
            end else begin
                tcycle_clk_count <= tcycle_clk_count + TCYCLE_CLOCK_HZ;
            end
        end
    end

    // M-Cycleのクロックティックパルス生成
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tcycle_clk_div <= 2'd0;
            mcycle_tick <= 0;
        end else begin
            mcycle_tick <= 0;
            if (tcycle_tick) begin
                mcycle_tick <= (tcycle_clk_div == 2'd0);
                tcycle_clk_div <= tcycle_clk_div + 2'd1;
            end
        end
    end

    // CPUコア
    sm83 cpu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_mcycle_tick(mcycle_tick),
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
        .i_tcycle_tick(tcycle_tick),
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
        .i_mcycle_tick(mcycle_tick),
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
    gbs_memory #(
        .ROM_FILE(ROM_FILE),
        .ROM_ADDRESS_BITS(ROM_ADDRESS_BITS)
    ) memory (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_address(address),
        .i_w_data(cpu_w_data),
        .i_re(cpu_re),
        .i_we(memory_we),
        .o_r_data(memory_r_data)
    );

endmodule
