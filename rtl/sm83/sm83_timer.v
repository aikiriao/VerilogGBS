`timescale 1ns/1ns
`include "sm83_register_address.vh"

module sm83_timer (
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_mcycle_tick, // M-Cycleティック信号
    input wire i_we_register, // レジスタ書き込みイネーブル
    input wire [15:0] i_address, // アドレス
    input wire [7:0] i_w_data, // 書き込みデータ
    output reg [7:0] o_r_data, // 読み込みデータ
    output wire o_timer_irq, // タイマー割り込み
    output wire o_vblank_irq // VBlank割り込み
);
    localparam MCYCLE_CLOCK_HZ = 1048576;

    // DIVレジスタがカウントアップする周期
    localparam DIVIDER_HZ = 16384;
    localparam DIVIDER_RATE_CLOCKS_INT = MCYCLE_CLOCK_HZ / DIVIDER_HZ;
    localparam DIVIDER_RATE_CLOCKS = DIVIDER_RATE_CLOCKS_INT[15:0];
    // VBlank周期
    // VBlankあたりのMCycleクロック数（PPUの1ライン456T-Cycles x 1フレーム154ライン=70224T-Cycleから）
    localparam MCYCLE_CLOCKS_PER_VBLANK = 70224 / 4;
    localparam VBLANK_CLOCKS = MCYCLE_CLOCKS_PER_VBLANK[23:0];

    // 各レジスタの書き込み信号
    wire div_write = i_we_register & (i_address == `HWREG_DIV_REGISTER);
    wire tima_write = i_we_register & (i_address == `HWREG_TIMA_TIMER_COUNTER);
    wire tma_write = i_we_register & (i_address == `HWREG_TMA_TIMER_MODULO);
    wire tac_write = i_we_register & (i_address == `HWREG_TAC_TIMER_CONTROL);

    // タイマーレジスタ
    reg [7:0] div_register;
    reg [7:0] tima_timer_counter;
    reg [7:0] tma_timer_modulo;
    reg [7:0] tac_timer_control;

    // 内部カウンタ値
    reg [15:0] div_clock_count;
    reg timer_enable;
    reg [8:0] timer_increment_cycle;
    reg [8:0] timer_clock_count;
    reg [23:0] vblank_clock_count;

    // レジスタ読み取り
    always @(*) begin
        case (i_address)
            `HWREG_DIV_REGISTER:
                o_r_data = div_register;
            `HWREG_TIMA_TIMER_COUNTER:
                o_r_data = tima_timer_counter;
            `HWREG_TMA_TIMER_MODULO:
                o_r_data = tma_timer_modulo;
            `HWREG_TAC_TIMER_CONTROL:
                o_r_data = tac_timer_control;
            default:
                o_r_data = 8'h00;
        endcase
    end

    // DIVタイマー更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            div_register <= 0;
            div_clock_count <= 0;
        end else if (div_write) begin
            // どの値の書き込みでも0にリセット
            div_register <= 0;
        end else if (i_mcycle_tick) begin
            if (div_clock_count >= DIVIDER_RATE_CLOCKS) begin
                div_register <= div_register + 8'd1;
                div_clock_count <= 16'd1;
            end else begin
                div_clock_count <= div_clock_count + 16'd1;
            end
        end
    end

    // タイマー更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            tima_timer_counter <= 0;
            tma_timer_modulo <= 0;
            tac_timer_control <= 0;
            timer_enable <= 0;
            timer_increment_cycle <= 256; // select == 0に相当
            timer_clock_count <= 0;
        end else if (tima_write) begin
            tima_timer_counter <= i_w_data;
        end else if (tma_write) begin
            tma_timer_modulo <= i_w_data;
        end else if (tac_write) begin 
            tac_timer_control <= i_w_data;
            timer_enable <= ((i_w_data & 8'h4) != 0);
            case (i_w_data[1:0])
                2'd0: timer_increment_cycle <= 9'd256;
                2'd1: timer_increment_cycle <= 9'd4;
                2'd2: timer_increment_cycle <= 9'd16;
                2'd3: timer_increment_cycle <= 9'd64;
            endcase
        end else if (timer_enable & i_mcycle_tick) begin
            if (timer_clock_count >= timer_increment_cycle) begin
                // 8bitの意味でオーバーフロー
                if (tima_timer_counter == 8'hFF) begin
                    // MODULOの値にリセット
                    tima_timer_counter <= tma_timer_modulo;
                end else begin
                    tima_timer_counter <= tima_timer_counter + 8'd1;
                end
                timer_clock_count <= 9'd1;
            end else begin
                timer_clock_count <= timer_clock_count + 9'd1;
            end
        end
    end

    // タイマー割り込み要求
    // タイマーのオーバーフロー後に割り込み要求が入る
    assign o_timer_irq = timer_enable & i_mcycle_tick & (timer_clock_count == 9'd1) & (tima_timer_counter == tma_timer_modulo);

    // VBlankタイマー更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            vblank_clock_count <= 0;
        end else if (i_mcycle_tick) begin
            if (vblank_clock_count >= VBLANK_CLOCKS) begin
                vblank_clock_count <= 24'd1;
            end else begin
                vblank_clock_count <= vblank_clock_count + 24'd1;
            end
        end
    end

    // VBlank割り込み要求
    assign o_vblank_irq = i_mcycle_tick & (vblank_clock_count >= VBLANK_CLOCKS);

endmodule
