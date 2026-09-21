`timescale 1ns/1ns
`include "sm83_register_address.vh"

module sm83 (
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire [7:0] i_r_data, // 読みだしたデータ
    output reg [15:0] o_address, // 読み書きアドレス
    output reg [7:0] o_w_data, // メモリ書き出しデータ
    output reg o_re, // メモリ読み出しイネーブル
    output reg o_we // メモリ書き出しイネーブル
);
    
    // 8bitレジスタインデックス
    localparam R8_B = 3'd0;
    localparam R8_C = 3'd1;
    localparam R8_D = 3'd2;
    localparam R8_E = 3'd3;
    localparam R8_H = 3'd4;
    localparam R8_L = 3'd5;
    localparam R8_HL_INDIRECT = 3'd6;
    localparam R8_A = 3'd7;

    // 16bitレジスタインデックス
    localparam R16_BC = 2'd0;
    localparam R16_DE = 2'd1;
    localparam R16_HL = 2'd2;
    localparam R16_SP = 2'd3;
    localparam R16STK_BC = 2'd0;
    localparam R16STK_DE = 2'd1;
    localparam R16STK_HL = 2'd2;
    localparam R16STK_AF = 2'd3;
    localparam R16MEM_BC = 2'd0;
    localparam R16MEM_DE = 2'd1;
    localparam R16MEM_HL_INC = 2'd2;
    localparam R16MEM_HF_DEC = 2'd3;

    // コンディションコード
    localparam COND_NZ = 2'd0; // NZ
    localparam COND_Z = 2'd1; // Z
    localparam COND_NC = 2'd2; // NC
    localparam COND_C = 2'd3; // C

    // フラグのビット位置
    localparam FLAG_Z = 3'd7; // ゼロフラグ
    localparam FLAG_N = 3'd6; // 引き算フラグ
    localparam FLAG_H = 3'd5; // ハーフキャリーフラグ
    localparam FLAG_C = 3'd4; // キャリーフラグ

    // オペコード
    localparam OP_NOP = 8'd0;
    localparam OP_LD16 = 8'd1;
    localparam OP_LD16_IMM16 = 8'd2;
    localparam OP_LD16_SP_TO_IMM16_INDIRECT = 8'd3;
    localparam OP_INC16 = 8'd4;
    localparam OP_DEC16 = 8'd5;
    localparam OP_ADD16 = 8'd6;
    localparam OP_INC = 8'd7;
    localparam OP_DEC = 8'd8;
    localparam OP_RLCA = 8'd9;
    localparam OP_RRCA = 8'd10;
    localparam OP_RLA = 8'd11;
    localparam OP_RRA = 8'd12;
    localparam OP_DAA = 8'd13;
    localparam OP_CPL = 8'd14;
    localparam OP_SCF = 8'd15;
    localparam OP_CCF = 8'd16;
    localparam OP_JR_NOCOND = 8'd17;
    localparam OP_JR = 8'd18;
    localparam OP_STOP = 8'd19;
    localparam OP_LD = 8'd20;
    localparam OP_LD_IMM8 = 8'd21;
    localparam OP_HALT = 8'd22;
    localparam OP_ADD = 8'd23;
    localparam OP_ADC = 8'd24;
    localparam OP_SUB = 8'd25;
    localparam OP_SBC = 8'd26;
    localparam OP_AND = 8'd27;
    localparam OP_XOR = 8'd28;
    localparam OP_OR = 8'd29;
    localparam OP_CP = 8'd30;
    localparam OP_ADD_IMM8 = 8'd31;
    localparam OP_ADC_IMM8 = 8'd32;
    localparam OP_SUB_IMM8 = 8'd33;
    localparam OP_SBC_IMM8 = 8'd34;
    localparam OP_AND_IMM8 = 8'd35;
    localparam OP_XOR_IMM8 = 8'd36;
    localparam OP_OR_IMM8 = 8'd37;
    localparam OP_CP_IMM8 = 8'd38;
    localparam OP_RET_COND = 8'd39;
    localparam OP_RET = 8'd40;
    localparam OP_RETI = 8'd41;
    localparam OP_JP_COND = 8'd42;
    localparam OP_JP = 8'd43;
    localparam OP_JP_HL = 8'd44;
    localparam OP_CALL_COND = 8'd45;
    localparam OP_CALL = 8'd46;
    localparam OP_RST = 8'd47;
    localparam OP_POP = 8'd48;
    localparam OP_PUSH = 8'd49;
    localparam OP_PREFIX = 8'd50; // 0xCB prefix code
    localparam OP_LDH = 8'd51;
    localparam OP_LDH_IMM8 = 8'd52;
    localparam OP_LD_IMM16 = 8'd53;
    localparam OP_ADD_SP = 8'd54;
    localparam OP_LD_SP_IMM8 = 8'd55;
    localparam OP_LD_SP_HL = 8'd56;
    localparam OP_DI = 8'd57;
    localparam OP_EI = 8'd58;
    // プレフィックス命令
    localparam OP_RLC = 8'd59; 
    localparam OP_RRC = 8'd60; 
    localparam OP_RL = 8'd61; 
    localparam OP_RR = 8'd62; 
    localparam OP_SLA = 8'd63; 
    localparam OP_SRA = 8'd64; 
    localparam OP_SWAP = 8'd65; 
    localparam OP_SRL = 8'd66; 
    localparam OP_BIT = 8'd67; 
    localparam OP_RES = 8'd68; 
    localparam OP_SET = 8'd69; 

    // レジスタ
    reg [7:0] r8[0:7]; // 8bitレジスタ
    reg [7:0] flags; // フラグレジスタ
    reg [15:0] sp; // スタックポインタ
    reg [15:0] pc; // プログラムカウンタ
    // 内部状態
    reg [7:0] mcycle; // マシンサイクル
    reg [7:0] opcode; // オペコード
    reg [2:0] r8_dst; // レジスタディステネーション識別
    reg r8_we; // レジスタ書き込みイネーブル
    reg [7:0] r8_w_data; // レジスタ書き込みデータ
    // 命令デコード用
    reg [7:0] tmpr; // 命令デコード用の一時レジスタ
    // 次状態
    reg [7:0] next_mcycle;
    reg [7:0] next_opcode;
    reg [15:0] next_pc;
    reg [7:0] next_flags;
    reg [15:0] next_sp;
    reg [7:0] next_tmpr;

    // オペコードのデコード
    function [7:0] decode_opcode(
        input [7:0] data
    );
    begin
        casez (data)
            8'b00000000: decode_opcode = OP_NOP;
            8'b00??0001: decode_opcode = OP_LD16_IMM16;
            8'b00??0010: decode_opcode = OP_LD16;
            8'b00??1010: decode_opcode = OP_LD16;
            8'b00001000: decode_opcode = OP_LD16_SP_TO_IMM16_INDIRECT;
            8'b00??0011: decode_opcode = OP_INC16;
            8'b00??1011: decode_opcode = OP_DEC16;
            8'b00??1001: decode_opcode = OP_ADD16;
            8'b00???110: decode_opcode = OP_LD_IMM8;
            8'b00000111: decode_opcode = OP_RLCA;
            8'b00001111: decode_opcode = OP_RRCA;
            8'b00010111: decode_opcode = OP_RLA;
            8'b00011111: decode_opcode = OP_RRA;
            8'b00100111: decode_opcode = OP_DAA;
            8'b00101111: decode_opcode = OP_CPL;
            8'b00110111: decode_opcode = OP_SCF;
            8'b00111111: decode_opcode = OP_CCF;
            8'b00011000: decode_opcode = OP_JR_NOCOND;
            8'b001??000: decode_opcode = OP_JR;
            8'b00010000: decode_opcode = OP_STOP;
            8'b01??????: begin
                if (data == 8'h76) begin 
                    decode_opcode = OP_HALT;
                end else begin
                    decode_opcode = OP_LD;
                end
            end
            8'b10000???: decode_opcode = OP_ADD;
            8'b10001???: decode_opcode = OP_ADC;
            8'b10010???: decode_opcode = OP_SUB;
            8'b10011???: decode_opcode = OP_SBC;
            8'b10100???: decode_opcode = OP_AND;
            8'b10101???: decode_opcode = OP_XOR;
            8'b10110???: decode_opcode = OP_OR;
            8'b10111???: decode_opcode = OP_CP;
            8'b11000110: decode_opcode = OP_ADD_IMM8;
            8'b11001110: decode_opcode = OP_ADC_IMM8;
            8'b11010110: decode_opcode = OP_SUB_IMM8;
            8'b11011110: decode_opcode = OP_SBC_IMM8;
            8'b11100110: decode_opcode = OP_AND_IMM8;
            8'b11101110: decode_opcode = OP_XOR_IMM8;
            8'b11110110: decode_opcode = OP_OR_IMM8;
            8'b11111110: decode_opcode = OP_CP_IMM8;
            8'b110??000: decode_opcode = OP_RET_COND;
            8'b11001001: decode_opcode = OP_RET;
            8'b11011001: decode_opcode = OP_RETI;
            8'b110??010: decode_opcode = OP_JP_COND;
            8'b11000011: decode_opcode = OP_JP;
            8'b11101001: decode_opcode = OP_JP_HL;
            8'b110??100: decode_opcode = OP_CALL_COND;
            8'b11001101: decode_opcode = OP_CALL;
            8'b11???111: decode_opcode = OP_RST;
            8'b11??0001: decode_opcode = OP_POP;
            8'b11??0101: decode_opcode = OP_PUSH;
            8'b11001011: decode_opcode = OP_PREFIX;
            8'b111?0010: decode_opcode = OP_LDH;
            8'b111?0000: decode_opcode = OP_LDH_IMM8;
            8'b111?1010: decode_opcode = OP_LD_IMM16;
            8'b11101000: decode_opcode = OP_ADD_SP;
            8'b11111000: decode_opcode = OP_LD_SP_IMM8;
            8'b11111001: decode_opcode = OP_LD_SP_HL;
            8'b11110011: decode_opcode = OP_DI;
            8'b11111011: decode_opcode = OP_EI;
            default: decode_opcode = OP_STOP;
        endcase
    end
    endfunction

    // オペコードのデコード
    function [7:0] decode_prefix_opcode(
        input [7:0] data
    );
    begin
        case (data)
            8'b00000???: decode_prefix_opcode = OP_RLC;
            8'b00001???: decode_prefix_opcode = OP_RRC;
            8'b00010???: decode_prefix_opcode = OP_RL;
            8'b00011???: decode_prefix_opcode = OP_RR;
            8'b00100???: decode_prefix_opcode = OP_SLA;
            8'b00101???: decode_prefix_opcode = OP_SRA;
            8'b00110???: decode_prefix_opcode = OP_SWAP;
            8'b00111???: decode_prefix_opcode = OP_SRL;
            8'b01??????: decode_prefix_opcode = OP_BIT;
            8'b10??????: decode_prefix_opcode = OP_RES;
            8'b11??????: decode_prefix_opcode = OP_SET;
            default: decode_prefix_opcode = OP_STOP;
        endcase
    end
    endfunction

    // 状態更新
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // 非同期リセット
            flags <= 8'd0;
            sp <= 16'd0;
            pc <= 16'd0;
            mcycle <= 8'd0;
            opcode <= 8'd0;
            tmpr <= 8'd0;
            r8[R8_B] <= 8'd0;
            r8[R8_C] <= 8'd0;
            r8[R8_D] <= 8'd0;
            r8[R8_E] <= 8'd0;
            r8[R8_H] <= 8'd0;
            r8[R8_L] <= 8'd0;
            r8[R8_HL_INDIRECT] <= 8'd0; // 使わないが念のため
            r8[R8_A] <= 8'd0;
        end else begin
            flags <= next_flags;
            sp <= next_sp;
            pc <= next_pc;
            mcycle <= next_mcycle;
            opcode <= next_opcode;
            tmpr <= next_tmpr;
            if (r8_we) begin
                r8[r8_dst] <= r8_w_data;
            end
        end
    end

    // 次状態の決定処理
    always @(*) begin
        // 状態は基本的に保持
        next_flags = flags;
        next_sp = sp;
        next_pc = pc;
        next_mcycle = mcycle;
        next_opcode = opcode;
        next_tmpr = tmpr;

        // バスは基本的に何もしない
        o_address = 16'h0000;
        o_w_data = 8'h00;
        o_re = 0;
        o_we = 0;

        // 8bitレジスタのライトバック信号
        r8_w_data = 8'h00;
        r8_dst = 3'd0;
        r8_we = 0;

        // マシンサイクル毎の処理
        if (mcycle == 8'd0) begin
            // オペコードのフェッチ

            // 次のデータを読みだす
            o_address = pc;
            o_re = 1;

            // 次状態
            next_opcode = decode_opcode(i_r_data);
            next_pc = pc + 16'd1;
            next_mcycle = 8'd1;
        end else begin
            // フェッチ以降はマイクロコードごとに異なる
            case (opcode)
                OP_NOP: begin
                    if (mcycle == 8'd1) begin
                        // 何もしない
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD16_IMM16: begin
                    // LD r16, imm16
                    if (mcycle == 8'd1) begin
                        // 次のデータを読みだす
                        o_address = pc;
                        o_re = 1;
                        next_pc = pc + 16'd1;
                        // レジスタ書き込み(SPのみは一時記録)
                        case (opcode[5:4])
                            R16_BC: begin
                                r8_w_data = i_r_data;
                                r8_dst = R8_C;
                                r8_we = 1;
                            end
                            R16_DE: begin
                                r8_w_data = i_r_data;
                                r8_dst = R8_E;
                                r8_we = 1;
                            end
                            R16_HL: begin
                                r8_w_data = i_r_data;
                                r8_dst = R8_L;
                                r8_we = 1;
                            end
                            R16_SP: begin
                                next_tmpr = i_r_data;
                            end
                        endcase
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = pc;
                        o_re = 1;
                        next_pc = pc + 16'd1;
                        case (opcode[5:4])
                            R16_BC: begin
                                r8_w_data = i_r_data;
                                r8_dst = R8_B;
                                r8_we = 1;
                            end
                            R16_DE: begin
                                r8_w_data = i_r_data;
                                r8_dst = R8_D;
                                r8_we = 1;
                            end
                            R16_HL: begin
                                r8_w_data = i_r_data;
                                r8_dst = R8_H;
                                r8_we = 1;
                            end
                            R16_SP: begin
                                next_sp = {i_r_data, tmpr};
                            end
                        endcase
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD16: begin
                end
                OP_INC16: begin
                end
                OP_DEC16: begin
                end
                OP_ADD16: begin
                end
                OP_LD_IMM8: begin
                end
                OP_RLCA: begin
                end
                OP_RRCA: begin
                end
                OP_RLA: begin
                end
                OP_RRA: begin
                end
                OP_DAA: begin
                end
                OP_CPL: begin
                end
                OP_SCF: begin
                end
                OP_CCF: begin
                end
                OP_JR_NOCOND: begin
                end
                OP_JR: begin
                end
                OP_STOP: begin
                end
                OP_HALT: begin
                end
                OP_LD: begin
                    if (mcycle == 8'd1) begin
                        if (opcode[5:3] == R8_HL_INDIRECT) begin
                            // LD (HL), r8
                            o_address = {r8[R8_H], r8[R8_L]};
                            o_w_data = r8[opcode[2:0]];
                            o_we = 1;
                        end else if (opcode[2:0] == R8_HL_INDIRECT) begin
                            // LD r8, (HL)
                            o_address = {r8[R8_H], r8[R8_L]};
                            o_re = 1;
                            r8_w_data = i_r_data;
                            r8_dst = opcode[5:3];
                            r8_we = 1;
                        end else begin
                            // LD r8, r8
                            r8_w_data = r8[opcode[2:0]];
                            r8_dst = opcode[5:3];
                            r8_we = 1;
                        end
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADD: begin
                end
                OP_ADC: begin
                end
                OP_SUB: begin
                end
                OP_SBC: begin
                end
                OP_AND: begin
                end
                OP_XOR: begin
                end
                OP_OR: begin
                end
                OP_CP: begin
                end
                OP_ADD_IMM8: begin
                end
                OP_ADC_IMM8: begin
                end
                OP_SUB_IMM8: begin
                end
                OP_SBC_IMM8: begin
                end
                OP_AND_IMM8: begin
                end
                OP_XOR_IMM8: begin
                end
                OP_OR_IMM8: begin
                end
                OP_CP_IMM8: begin
                end
                OP_RET_COND: begin
                end
                OP_RET: begin
                end
                OP_RETI: begin
                end
                OP_JP_COND: begin
                end
                OP_JP: begin
                end
                OP_JP_HL: begin
                end
                OP_CALL_COND: begin
                end
                OP_CALL: begin
                end
                OP_RST: begin
                end
                OP_POP: begin
                end
                OP_PUSH: begin
                end
                OP_PREFIX: begin
                end
                OP_LDH: begin
                end
                OP_LDH_IMM8: begin
                end
                OP_LD_IMM16: begin
                end
                OP_ADD_SP: begin
                end
                OP_LD_SP_IMM8: begin
                end
                OP_LD_SP_HL: begin
                end
                OP_DI: begin
                end
                OP_EI: begin
                end
                default: begin
                    // TODO
                end
            endcase
        end
    end

endmodule
