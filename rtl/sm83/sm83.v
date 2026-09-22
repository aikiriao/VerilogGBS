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

    `include "sm83_defs.vh"
    
    // レジスタ
    reg [7:0] r8[0:7]; // 8bitレジスタ
    reg [7:0] flags; // フラグレジスタ
    reg [15:0] sp; // スタックポインタ
    reg [15:0] pc; // プログラムカウンタ
    // 内部状態
    reg [7:0] mcycle; // マシンサイクル
    reg [7:0] opcode; // オペコード
    reg [7:0] op; // オペコードのデコード結果の命令種別
    reg [2:0] r8_dst; // 8bitレジスタディステネーション識別
    reg r8_we; // 8bitレジスタ書き込みイネーブル
    reg [7:0] r8_w_data; // 8bitレジスタ書き込みデータ
    // 命令デコード用
    reg [1:0] r16_dst; // 16bitレジスタディステネーション識別
    reg r16_we; // 16bitレジスタ書き込みイネーブル
    reg [15:0] r16_w_data; // 16bitレジスタ書き込みデータ
    // 命令デコード用
    reg [7:0] tmpr; // 命令デコード用の一時レジスタ
    // 次状態
    reg [7:0] next_mcycle;
    reg [7:0] next_opcode;
    reg [7:0] next_op;
    reg [15:0] next_pc;
    reg [7:0] next_flags;
    reg [15:0] next_sp;
    reg [7:0] next_tmpr;

    // 16bitレジスタ値の取得
    function automatic [15:0] get_r16(
        input [1:0] r16
    );
        case (r16)
            R16_BC: get_r16 = {r8[R8_B], r8[R8_C]};
            R16_DE: get_r16 = {r8[R8_D], r8[R8_E]};
            R16_HL: get_r16 = {r8[R8_H], r8[R8_L]};
            R16_SP: get_r16 = sp;
            default: get_r16 = 16'd0;
        endcase
    endfunction

    // 16bit加算
    // 結果をフラグとともに {Z, H, C, result} で返す
    function automatic [18:0] add16(
        input [15:0] v1,
        input [15:0] v2,
        input carry
    );
        reg [16:0] sum;

        begin
            sum = {1'b0, v1} + {1'b0, v2} + carry;
            add16 = {
                (sum[15:0] === 0),
                ((v1[12] ^ v2[12] ^ sum[12]) !== 0),
                sum[16],
                sum[15:0]
                };
        end
    endfunction

    // 8bit加算
    // 結果をフラグとともに {Z, H, C, result} で返す
    function automatic [10:0] add8(
        input [7:0] v1,
        input [7:0] v2,
        input carry
    );
        reg [8:0] sum;

        begin
            sum = {1'b0, v1} + {1'b0, v2} + carry;
            add8 = {
                (sum[7:0] === 0),
                ((v1[4] ^ v2[4] ^ sum[4]) !== 0),
                sum[8],
                sum[7:0]
                };
        end
    endfunction

    // 8bit減算
    // 結果をフラグとともに {Z, H, C, result} で返す
    function automatic [10:0] sub8(
        input [7:0] v1,
        input [7:0] v2,
        input carry
    );
        reg [7:0] sub;

        begin
            sub = v1 - v2 - carry;
            sub8 = {
                (sub[7:0] === 0),
                (((v2 & 8'h0F) + carry) > (v1 & 8'h0F)),
                ((v2 + carry) > v1),
                sub[7:0]
                };
        end
    endfunction

    // オペコードのデコード
    function automatic [7:0] decode_opcode(
        input [7:0] data
    );
    begin
        casez (data)
            8'b00000000: decode_opcode = OP_NOP;
            8'b00??0001: decode_opcode = OP_LD16_IMM16;
            8'b00??0010: decode_opcode = OP_LD_A_TO_INDIRECT;
            8'b00??1010: decode_opcode = OP_LD_INDIRECT_TO_A;
            8'b00001000: decode_opcode = OP_LD16_SP_TO_IMM16_INDIRECT;
            8'b00??0011: decode_opcode = OP_INC16;
            8'b00??1011: decode_opcode = OP_DEC16;
            8'b00??1001: decode_opcode = OP_ADD16;
            8'b00???100: decode_opcode = OP_INC;
            8'b00???101: decode_opcode = OP_DEC;
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
    function automatic [7:0] decode_prefix_opcode(
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
            op <= OP_NOP;
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
            op <= next_op;
            opcode <= next_opcode;
            tmpr <= next_tmpr;
            if (r8_we) begin
                r8[r8_dst] <= r8_w_data;
            end
            if (r16_we) begin
                case (r16_dst)
                    R16_BC: {r8[R8_B], r8[R8_C]} <= r16_w_data;
                    R16_DE: {r8[R8_D], r8[R8_E]} <= r16_w_data;
                    R16_HL: {r8[R8_H], r8[R8_L]} <= r16_w_data;
                    R16_SP: sp <= r16_w_data;
                endcase
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
        next_op = op;
        next_tmpr = tmpr;

        // バスは基本的に何もしない
        o_address = 16'h0000;
        o_w_data = 8'h00;
        o_re = 0;
        o_we = 0;

        // 8bit/16bitレジスタのライトバック信号
        r8_w_data = 8'h00;
        r8_dst = 3'd0;
        r8_we = 0;
        r16_w_data = 16'h0000;
        r16_dst = 2'd0;
        r16_we = 0;

        // マシンサイクル毎の処理
        if (mcycle == 8'd0) begin
            // オペコードのフェッチ

            // 次のデータを読みだす
            o_address = pc;
            o_re = 1;

            // 次状態
            next_opcode = i_r_data;
            next_op = decode_opcode(i_r_data);
            next_pc = pc + 16'd1;
            next_mcycle = 8'd1;
        end else begin
            // フェッチ以降はマイクロコードごとに異なる
            case (op)
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
                        next_tmpr = i_r_data;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = pc;
                        o_re = 1;
                        next_pc = pc + 16'd1;
                        r16_w_data = {i_r_data, tmpr};
                        r16_dst = opcode[5:4];
                        r16_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD_A_TO_INDIRECT: begin
                    // LD [r16], a
                    if (mcycle == 8'd1) begin
                        case (opcode[5:4]) 
                            R16MEM_BC: o_address = get_r16(R16_BC);
                            R16MEM_DE: o_address = get_r16(R16_DE);
                            R16MEM_HL_INC: begin
                                o_address = get_r16(R16_HL);
                                // HLを増やす
                                r16_w_data = get_r16(R16_HL) + 16'd1;
                                r16_dst = R16_HL;
                                r16_we = 1;
                            end
                            R16MEM_HL_DEC: begin
                                o_address = get_r16(R16_HL);
                                // HLを減らす
                                r16_w_data = get_r16(R16_HL) - 16'd1;
                                r16_dst = R16_HL;
                                r16_we = 1;
                            end
                        endcase
                        o_we = 1;
                        o_w_data = r8[R8_A];
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD_INDIRECT_TO_A: begin
                    // LD a, [r16]
                    if (mcycle == 8'd1) begin
                        case (opcode[5:4]) 
                            R16MEM_BC: o_address = get_r16(R16_BC);
                            R16MEM_DE: o_address = get_r16(R16_DE);
                            R16MEM_HL_INC: begin
                                o_address = get_r16(R16_HL);
                                // HLを増やす
                                r16_w_data = get_r16(R16_HL) + 16'd1;
                                r16_dst = R16_HL;
                                r16_we = 1;
                            end
                            R16MEM_HL_DEC: begin
                                o_address = get_r16(R16_HL);
                                // HLを減らす
                                r16_w_data = get_r16(R16_HL) - 16'd1;
                                r16_dst = R16_HL;
                                r16_we = 1;
                            end
                        endcase
                        r8_w_data = i_r_data;
                        r8_dst = R8_A;
                        r8_we = 1;
                        o_re = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_INC16: begin
                    // INC r16
                    if (mcycle == 8'd1) begin
                        r16_w_data = get_r16(opcode[5:4]) + 16'd1;
                        r16_dst = opcode[5:4];
                        r16_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_DEC16: begin
                    // DEC r16
                    if (mcycle == 8'd1) begin
                        r16_w_data = get_r16(opcode[5:4]) - 16'd1;
                        r16_dst = opcode[5:4];
                        r16_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADD16: begin
                    // ADD HL, r16
                    if (mcycle == 8'd1) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r16_w_data} = add16(get_r16(R16_HL), get_r16(opcode[5:4]), flags[FLAG_C]);
                        next_flags[FLAG_N] = 0;
                        r16_dst = R16_HL;
                        r16_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_INC: begin
                    // INC r8
                    if (mcycle == 8'd1) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(r8[opcode[5:3]], 8'd1, 0);
                        next_flags[FLAG_C] = flags[FLAG_C]; // キャリーフラグは変えない
                        next_flags[FLAG_N] = 0;
                        r8_dst = opcode[5:3];
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_DEC: begin
                    // DEC r8
                    if (mcycle == 8'd1) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(r8[opcode[5:3]], 8'd1, 0);
                        next_flags[FLAG_C] = flags[FLAG_C]; // キャリーフラグは変えない
                        next_flags[FLAG_N] = 1;
                        r8_dst = opcode[5:3];
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
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
