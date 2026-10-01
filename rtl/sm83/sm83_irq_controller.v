`timescale 1ns/1ns
`include "sm83_register_address.vh"

module sm83_irq_controller #(
    parameter CLOCK_HZ = 1048576 // クロック動作周波数
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_register, // レジスタ書き込みイネーブル
    input wire [15:0] i_address, // アドレス
    input wire [7:0] i_w_data, // 書き込みデータ
    input wire i_vblank_irq, // V同期信号割り込み信号
    input wire i_lcd_irq, // LCD割り込み信号
    input wire i_timer_irq, // タイマー割り込み信号
    input wire i_serial_irq, // シリアルデータ割り込み信号
    input wire i_joypad_irq, // ジョイパッド割り込み信号
    input wire [4:0] i_irq_ack, // 割り込み処理済み信号(from SM83)
    output reg [7:0] o_r_data, // 読み込みデータ
    output wire [4:0] o_irq_pending, // 割り込み要求信号(to SM83)
);
    // 割り込み信号をまとめた信号
    wire i_irq = {i_joypad_irq, i_serial_irq, i_timer_irq, i_lcd_irq, i_vblank_irq};

    // 各レジスタの書き込み信号
    wire if_write = i_we_register & (i_address == `HWREG_IF_INTERRUPT_FLAG);
    wire ie_write = i_we_register & (i_address == `HWREG_IE_INTERRUPT_ENABLE);

    reg [4:0] if_reg; // 割り込みフラグ
    reg [4:0] ie_reg; // 割り込み有効フラグ

    // レジスタ読み取り
    always @(*) begin
        case (i_address)
            `HWREG_IF_INTERRUPT_FLAG:
                o_r_data = {3'd0, if_reg};
            `HWREG_IE_INTERRUPT_ENABLE:
                o_r_data = {3'd0, ie_reg};
            default:
                o_r_data = 8'h00;
        endcase
    end

    // 割り込み有効フラグ更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            ie_reg <= 0;
        end else if (ie_write) begin
            ie_reg <= i_w_data[4:0];
        end
    end

    // 割り込みフラグ更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            if_reg <= 0;
        end else if (if_write) begin
            if_reg <= i_w_data[4:0];
        end else if ((|i_irq) | (|i_irq_ack)) begin
            // 割り込み要求信号をラッチ・割り込み処理済みの信号をクリア
            // 割り込み要求と割り込み処理済みが同時に来た場合は要求を残す
            if_reg <= i_irq | (if_reg & (~i_irq_ack));
        end
    end

    // 割り込み要求信号
    assign o_irq_pending = if_reg & ie_reg;

endmodule
