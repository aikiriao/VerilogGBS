`timescale 1ns/1ns
`include "sm83_register_address.vh"

module sm83 (
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_mcycle_ce, // マシンサイクルクロック有効か
    input wire [7:0] i_r_data, // 読みだしたデータ
    input wire [4:0] i_irq_pending, // 割り込み要求信号
    output reg [15:0] o_address, // 読み書きアドレス
    output reg [7:0] o_w_data, // メモリ書き出しデータ
    output reg o_re, // メモリ読み出しイネーブル
    output reg o_we, // メモリ書き出しイネーブル
    output reg [4:0] o_irq_ack // 割り込み応答信号
);

    `include "sm83_defs.vh"
    
    // レジスタ
    reg [7:0] a; // 8bitレジスタ
    reg [7:0] b; // 8bitレジスタ
    reg [7:0] c; // 8bitレジスタ
    reg [7:0] d; // 8bitレジスタ
    reg [7:0] e; // 8bitレジスタ
    reg [7:0] h; // 8bitレジスタ
    reg [7:0] l; // 8bitレジスタ
    reg [7:0] flags; // フラグレジスタ
    reg [15:0] sp; // スタックポインタ
    reg [15:0] pc; // プログラムカウンタ
    reg ime; // 割り込みイネーブル
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
    reg r16stk_we; // 16bitスタックレジスタ書き込みイネーブル
    reg [15:0] r16_w_data; // 16bitレジスタ書き込みデータ
    // 命令デコード用
    reg [15:0] tmpr; // 命令デコード用の一時レジスタ
    // 次状態
    reg [7:0] next_mcycle;
    reg [7:0] next_opcode;
    reg [7:0] next_op;
    reg [15:0] next_pc;
    reg [7:0] next_flags;
    reg [15:0] next_sp;
    reg [15:0] next_tmpr;
    reg next_ime;

    // 8bitレジスタ値の取得
    function automatic [7:0] get_r8(
        input [2:0] r8
    );
        case (r8)
            R8_A: get_r8 = a;
            R8_B: get_r8 = b;
            R8_C: get_r8 = c;
            R8_D: get_r8 = d;
            R8_E: get_r8 = e;
            R8_H: get_r8 = h;
            R8_L: get_r8 = l;
            default: get_r8 = 8'd0;
        endcase
    endfunction

    // 16bitレジスタ値の取得
    function automatic [15:0] get_r16(
        input [1:0] r16
    );
        case (r16)
            R16_BC: get_r16 = {b, c};
            R16_DE: get_r16 = {d, e};
            R16_HL: get_r16 = {h, l};
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
                (({1'b0, v2} + carry) > {1'b0, v1}),
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
            8'b00001000: decode_opcode = OP_LD16_SP_TO_IMM16_DIRECT;
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
            8'b111?1010: decode_opcode = OP_LD_IMM16_DIRECT;
            8'b11101000: decode_opcode = OP_ADD_SP;
            8'b11111000: decode_opcode = OP_LD_HL_SP_IMM8;
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
        casez (data)
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
            tmpr <= 16'd0;
            ime <= 1'b0;
            a <= 8'd0;
            b <= 8'd0;
            c <= 8'd0;
            d <= 8'd0;
            e <= 8'd0;
            h <= 8'd0;
            l <= 8'd0;
        end else if (i_mcycle_ce) begin
            flags <= next_flags;
            sp <= next_sp;
            pc <= next_pc;
            mcycle <= next_mcycle;
            op <= next_op;
            opcode <= next_opcode;
            tmpr <= next_tmpr;
            ime <= next_ime;
            if (r8_we) begin
                case (r8_dst)
                    R8_A: a <= r8_w_data;
                    R8_B: b <= r8_w_data;
                    R8_C: c <= r8_w_data;
                    R8_D: d <= r8_w_data;
                    R8_E: e <= r8_w_data;
                    R8_H: h <= r8_w_data;
                    R8_L: l <= r8_w_data;
                    default: a <= a; // 何もしない
                endcase
            end
            if (r16_we) begin
                case (r16_dst)
                    R16_BC: {b, c} <= r16_w_data;
                    R16_DE: {d, e} <= r16_w_data;
                    R16_HL: {h, l} <= r16_w_data;
                    R16_SP: sp <= r16_w_data;
                endcase
            end
            if (r16stk_we) begin
                case (r16_dst)
                    R16STK_BC: {b, c} <= r16_w_data;
                    R16STK_DE: {d, e} <= r16_w_data;
                    R16STK_HL: {h, l} <= r16_w_data;
                    R16STK_AF: {a, flags} <= r16_w_data;
                endcase
            end
        end
    end

    // 次状態の決定論理
    wire [7:0] fetch_opcode = i_r_data;
    wire [7:0] fetch_op = decode_opcode(fetch_opcode);
    always @(*) begin
        // 状態は基本的に保持
        next_flags = flags;
        next_sp = sp;
        next_pc = pc;
        next_mcycle = mcycle;
        next_opcode = opcode;
        next_op = op;
        next_tmpr = tmpr;
        next_ime = ime;

        // バスは基本的に何もしない
        o_address = 16'h0000;
        o_w_data = 8'h00;
        o_re = 0;
        o_we = 0;

        // 割り込み応答信号
        o_irq_ack = 5'b00000;

        // 8bit/16bitレジスタのライトバック信号
        r8_w_data = 8'h00;
        r8_dst = 3'd0;
        r8_we = 0;
        r16_w_data = 16'h0000;
        r16_dst = 2'd0;
        r16_we = 0;
        r16stk_we = 0;

        if (ime && (|i_irq_pending)) begin
            // 割り込み処理
            // 現在のPCをスタックにプッシュ
            if (mcycle == 8'd0) begin
                o_address = sp - 16'd1;
                o_we = 1;
                o_w_data = pc[15:8];
                next_sp = sp - 16'd1;
                next_mcycle = 8'd1;
            end else if (mcycle == 8'd1) begin
                o_address = sp - 16'd1;
                o_we = 1;
                o_w_data = pc[7:0];
                next_sp = sp - 16'd1;
                next_mcycle = 8'd2;
            end else if (mcycle == 8'd2) begin
                // 割り込みフラグをクリアし、PCを更新
                next_ime = 0; 
                casez (i_irq_pending)
                    5'b????1: begin
                        next_pc = 16'h0040;
                        o_irq_ack = 5'b00001;
                    end
                    5'b???10: begin
                        next_pc = 16'h0048;
                        o_irq_ack = 5'b00010;
                    end
                    5'b??100: begin
                        next_pc = 16'h0050;
                        o_irq_ack = 5'b00100;
                    end
                    5'b?1000: begin
                        next_pc = 16'h0058;
                        o_irq_ack = 5'b01000;
                    end
                    5'b10000: begin
                        next_pc = 16'h0060;
                        o_irq_ack = 5'b10000;
                    end
                    default: begin
                        /* BUG */
                    end
                endcase
                next_mcycle = 8'd0;
            end
        end else if (mcycle == 8'd0) begin
            // マシンサイクル毎の処理
            // PCにあるデータを読みだす
            o_address = pc;
            o_re = 1;
            
            // オペコードの読み出し・デコード
            next_opcode = fetch_opcode;
            next_op = fetch_op;
            
            // 次状態
            next_pc = pc + 16'd1;
            next_mcycle = 8'd1;
            
            // フェッチしたオペコードを即時に使用する命令の処理
            // IMPORTANT: メモリから命令をデコードしているので同一サイクル内でメモリアクセスは禁止
            case (fetch_op)
                OP_NOP: begin
                    // NOP
                    next_mcycle = 8'd0;
                end
                OP_INC16: begin
                    // INC r16
                    r16_w_data = get_r16(fetch_opcode[5:4]) + 16'd1;
                    r16_dst = fetch_opcode[5:4];
                    r16_we = 1;
                    next_mcycle = 8'd1;
                end
                OP_DEC16: begin
                    // DEC r16
                    r16_w_data = get_r16(fetch_opcode[5:4]) - 16'd1;
                    r16_dst = fetch_opcode[5:4];
                    r16_we = 1;
                    next_mcycle = 8'd1;
                end
                OP_ADD16: begin
                    // ADD HL, r16
                    {next_flags[FLAG_Z],
                        next_flags[FLAG_H],
                        next_flags[FLAG_C],
                        r16_w_data} = add16(get_r16(R16_HL), get_r16(fetch_opcode[5:4]), flags[FLAG_C]);
                    next_flags[FLAG_N] = 0;
                    r16_dst = R16_HL;
                    r16_we = 1;
                    next_mcycle = 8'd1;
                end
                OP_INC: begin
                    // INC r8
                    if (fetch_opcode[5:3] != R8_HL_INDIRECT) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(get_r8(fetch_opcode[5:3]), 8'd1, 0);
                        next_flags[FLAG_C] = flags[FLAG_C]; // キャリーフラグは変えない
                        next_flags[FLAG_N] = 0;
                        r8_dst = fetch_opcode[5:3];
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_DEC: begin
                    // DEC r8
                    if (fetch_opcode[5:3] != R8_HL_INDIRECT) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(get_r8(fetch_opcode[5:3]), 8'd1, 0);
                        next_flags[FLAG_C] = flags[FLAG_C]; // キャリーフラグは変えない
                        next_flags[FLAG_N] = 1;
                        r8_dst = fetch_opcode[5:3];
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_RLCA: begin
                    // RLCA
                    r8_w_data = {a[6:0], a[7]};
                    r8_dst = R8_A;
                    r8_we = 1;
                    next_flags[FLAG_Z] = 0;
                    next_flags[FLAG_N] = 0;
                    next_flags[FLAG_H] = 0;
                    next_flags[FLAG_C] = a[7];
                    next_mcycle = 8'd0;
                end
                OP_RRCA: begin
                    // RRCA
                    r8_w_data = {a[0], a[7:1]};
                    r8_dst = R8_A;
                    r8_we = 1;
                    next_flags[FLAG_Z] = 0;
                    next_flags[FLAG_N] = 0;
                    next_flags[FLAG_H] = 0;
                    next_flags[FLAG_C] = a[0];
                    next_mcycle = 8'd0;
                end
                OP_RLA: begin
                    // RLA
                    r8_w_data = {a[6:0], flags[FLAG_C]};
                    r8_dst = R8_A;
                    r8_we = 1;
                    next_flags[FLAG_Z] = 0;
                    next_flags[FLAG_N] = 0;
                    next_flags[FLAG_H] = 0;
                    next_flags[FLAG_C] = a[7];
                    next_mcycle = 8'd0;
                end
                OP_RRA: begin
                    // RRA
                    r8_w_data = {flags[FLAG_C], a[7:1]};
                    r8_dst = R8_A;
                    r8_we = 1;
                    next_flags[FLAG_Z] = 0;
                    next_flags[FLAG_N] = 0;
                    next_flags[FLAG_H] = 0;
                    next_flags[FLAG_C] = a[0];
                    next_mcycle = 8'd0;
                end
                OP_CPL: begin
                    // CPL
                    r8_w_data = ~a;
                    r8_dst = R8_A;
                    r8_we = 1;
                    next_flags[FLAG_N] = 1;
                    next_flags[FLAG_H] = 1;
                    next_mcycle = 8'd0;
                end
                OP_SCF: begin
                    // SCF
                    next_flags[FLAG_C] = 1;
                    next_flags[FLAG_N] = 0;
                    next_flags[FLAG_H] = 0;
                    next_mcycle = 8'd0;
                end
                OP_DAA: begin
                    // TODO: 何もしない
                end
                OP_CCF: begin
                    // CCF
                    next_flags[FLAG_C] = ~flags[FLAG_C];
                    next_flags[FLAG_N] = 0;
                    next_flags[FLAG_H] = 0;
                    next_mcycle = 8'd0;
                end
                OP_LD: begin
                   if ((fetch_opcode[5:3] != R8_HL_INDIRECT) && (fetch_opcode[2:0] != R8_HL_INDIRECT)) begin
                       // LD r8, r8
                       r8_w_data = get_r8(fetch_opcode[2:0]);
                       r8_dst = fetch_opcode[5:3];
                       r8_we = 1;
                       next_mcycle = 8'd0;
                   end
                end
                OP_ADD: begin
                    // ADD r8
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(a, get_r8(fetch_opcode[2:0]), 0);
                        next_flags[FLAG_N] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADC: begin
                    // ADC r8
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(a, get_r8(fetch_opcode[2:0]), flags[FLAG_C]);
                        next_flags[FLAG_N] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_SUB: begin
                    // SUB r8
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(a, get_r8(fetch_opcode[2:0]), 0);
                        next_flags[FLAG_N] = 1;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_SBC: begin
                    // SBC r8
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(a, get_r8(fetch_opcode[2:0]), flags[FLAG_C]);
                        next_flags[FLAG_N] = 1;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_AND: begin
                    // AND r8
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        r8_w_data = a & get_r8(fetch_opcode[2:0]);
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 1;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_XOR: begin
                    // XOR r8
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        r8_w_data = a ^ get_r8(fetch_opcode[2:0]);
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_OR: begin
                    // OR r8
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        r8_w_data = a | get_r8(fetch_opcode[2:0]);
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_CP: begin
                    // CP r8
                    // Aを更新しないことを除きSUBと同等
                    if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            next_tmpr[7:0]} = sub8(a, get_r8(fetch_opcode[2:0]), 0);
                        next_flags[FLAG_N] = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_STOP: begin
                    // TODO: 未実装。PCを止める
                    next_pc = pc;
                end
                OP_HALT: begin
                    // TODO: 未実装。PCを止める
                    next_pc = pc;
                end
                OP_JP_HL: begin
                    // JP HL
                    next_pc = get_r16(R16_HL);
                    next_mcycle = 8'd0;
                end
                OP_LD_SP_HL: begin
                    // LD SP, HL
                    next_sp = get_r16(R16_HL);
                    next_mcycle = 8'd1; // NOTE: 既に処理は終わっているが2サイクルに合わせる
                end
                OP_DI: begin
                    // DI
                    // 実機では即時反映だが本実装では次クロックから
                    next_ime = 0;
                    next_mcycle = 8'd0;
                end
                OP_EI: begin
                    // EI
                    next_ime = 1;
                    next_mcycle = 8'd0;
                end
                default: begin 
                end
            endcase
        end else begin
            // フェッチ済みのオペコードを使った処理
            case (op)
                OP_LD16_IMM16: begin
                    // LD r16, imm16
                    if (mcycle == 8'd1) begin
                        // 次のデータを読みだす
                        o_address = pc;
                        o_re = 1;
                        next_pc = pc + 16'd1;
                        next_tmpr[7:0] = i_r_data;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = pc;
                        o_re = 1;
                        next_pc = pc + 16'd1;
                        r16_w_data = {i_r_data, tmpr[7:0]};
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
                        o_w_data = a;
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
                OP_LD16_SP_TO_IMM16_DIRECT: begin
                    // LD [imm16], SP
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        next_pc = pc + 16'd1;
                        next_tmpr[7:0] = i_r_data;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = pc;
                        o_re = 1;
                        next_pc = pc + 16'd1;
                        next_tmpr = {i_r_data, tmpr[7:0]};
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = tmpr;
                        o_we = 1;
                        o_w_data = sp[7:0];
                        next_mcycle = 8'd4;
                    end else if (mcycle == 8'd4) begin
                        o_address = tmpr + 16'd1;
                        o_we = 1;
                        o_w_data = sp[15:8];
                        next_mcycle = 8'd0;
                    end
                end
                OP_INC16: begin
                    // NOTE: 既に処理は終わっているがサイクルを合わせる
                    if (mcycle == 8'd1) begin
                        next_mcycle = 8'd0;
                    end
                end
                OP_DEC16: begin
                    // NOTE: 既に処理は終わっているがサイクルを合わせる
                    if (mcycle == 8'd1) begin
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADD16: begin
                    // NOTE: 既に処理は終わっているがサイクルを合わせる
                    if (mcycle == 8'd1) begin
                        next_mcycle = 8'd0;
                    end
                end
                OP_INC: begin
                    // INC (HL)
                    // NOTE: INC r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            o_w_data} = add8(tmpr[7:0], 8'd1, 0);
                        next_flags[FLAG_C] = flags[FLAG_C]; // キャリーフラグは変えない
                        next_flags[FLAG_N] = 0;
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_DEC: begin
                    // DEC (HL)
                    // NOTE: DEC r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            o_w_data} = sub8(tmpr[7:0], 8'd1, 0);
                        next_flags[FLAG_C] = flags[FLAG_C]; // キャリーフラグは変えない
                        next_flags[FLAG_N] = 1;
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD_IMM8: begin
                    // LD r8, imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        r8_w_data = i_r_data;
                        r8_dst = opcode[5:3];
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_JR_NOCOND: begin
                    // JR emm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        // 符号拡張して符号付き加算
                        next_pc = pc + 16'd1 + $signed({{8{i_r_data[7]}}, i_r_data});
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_JR: begin
                    // JR cc, emm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_pc = pc + 16'd1;
                        if (((opcode[4:3] == COND_NZ) && (!flags[FLAG_Z]))
                            || ((opcode[4:3] == COND_Z) && (flags[FLAG_Z]))
                            || ((opcode[4:3] == COND_NC) && (!flags[FLAG_C]))
                            || ((opcode[4:3] == COND_C) && (flags[FLAG_C]))) begin
                            next_mcycle = 8'd2;
                        end else begin
                            next_mcycle = 8'd0;
                        end
                    end else if (mcycle == 8'd2) begin
                        next_pc = pc + $signed({{8{tmpr[7]}}, tmpr[7:0]});
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD: begin
                    // NOTE: LD r8, r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        if (opcode[5:3] == R8_HL_INDIRECT) begin
                            // LD (HL), r8
                            o_address = get_r16(R16_HL);
                            o_w_data = get_r8(opcode[2:0]);
                            o_we = 1;
                        end else if (opcode[2:0] == R8_HL_INDIRECT) begin
                            // LD r8, (HL)
                            o_address = get_r16(R16_HL);
                            o_re = 1;
                            r8_w_data = i_r_data;
                            r8_dst = opcode[5:3];
                            r8_we = 1;
                        end
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADD: begin
                    // ADD (HL)
                    // NOTE: ADD r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(a, i_r_data, 0);
                        next_flags[FLAG_N] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADC: begin
                    // ADC (HL)
                    // NOTE: ADC r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(a, i_r_data, flags[FLAG_C]);
                        next_flags[FLAG_N] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_SUB: begin
                    // SUB (HL)
                    // NOTE: SUB r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(a, i_r_data, 0);
                        next_flags[FLAG_N] = 1;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_SBC: begin
                    // SBC (HL)
                    // NOTE: SBC r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(a, i_r_data, flags[FLAG_C]);
                        next_flags[FLAG_N] = 1;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_AND: begin
                    // AND (HL)
                    // NOTE: AND r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        r8_w_data = a & i_r_data;
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 1;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_XOR: begin
                    // XOR (HL)
                    // NOTE: XOR r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        r8_w_data = a ^ i_r_data;
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_OR: begin
                    // OR (HL)
                    // NOTE: OR r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        r8_w_data = a | i_r_data;
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_CP: begin
                    // CP r8 Aを更新しないことを除きSUBと同等
                    // NOTE: CP r8は1サイクル目で終わっている
                    if (mcycle == 8'd1) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            next_tmpr[7:0]} = sub8(a, i_r_data, 0);
                        next_flags[FLAG_N] = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADD_IMM8: begin
                    // ADD imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(a, i_r_data, 0);
                        next_flags[FLAG_N] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_ADC_IMM8: begin
                    // ADC imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = add8(a, i_r_data, flags[FLAG_C]);
                        next_flags[FLAG_N] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_SUB_IMM8: begin
                    // SUB imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(a, i_r_data, 0);
                        next_flags[FLAG_N] = 1;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_SBC_IMM8: begin
                    // SBC imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            r8_w_data} = sub8(a, i_r_data, flags[FLAG_C]);
                        next_flags[FLAG_N] = 1;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_AND_IMM8: begin
                    // AND imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        r8_w_data = a & i_r_data;
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 1;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_XOR_IMM8: begin
                    // XOR imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        r8_w_data = a ^ i_r_data;
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_OR_IMM8: begin
                    // OR imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        r8_w_data = a | i_r_data;
                        next_flags[FLAG_Z] = (r8_w_data == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = 0;
                        r8_dst = R8_A;
                        r8_we = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_CP_IMM8: begin
                    // CP imm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        {next_flags[FLAG_Z],
                            next_flags[FLAG_H],
                            next_flags[FLAG_C],
                            next_tmpr[7:0]} = sub8(a, i_r_data, 0);
                        next_flags[FLAG_N] = 1;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_RET_COND: begin
                    // RET cc
                    if (mcycle == 8'd1) begin
                        // 条件成立なら次のサイクルへ。未成立なら終了し次の命令へ
                        case (opcode[4:3]) 
                            COND_NZ: next_mcycle = (!flags[FLAG_Z]) ? 8'd2 : 8'd0;
                            COND_Z: next_mcycle = (flags[FLAG_Z]) ? 8'd2 : 8'd0;
                            COND_NC: next_mcycle = (!flags[FLAG_C]) ? 8'd2 : 8'd0;
                            COND_C: next_mcycle = (flags[FLAG_C]) ? 8'd2 : 8'd0;
                        endcase
                    end else if (mcycle == 8'd2) begin
                        o_address = sp;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_sp = sp + 16'd1;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = sp;
                        o_re = 1;
                        next_pc = {i_r_data, tmpr[7:0]};
                        next_sp = sp + 16'd1;
                        next_mcycle = 8'd4;
                    end else if (mcycle == 8'd4) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_RET: begin
                    if (mcycle == 8'd1) begin
                        o_address = sp;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_sp = sp + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = sp;
                        o_re = 1;
                        next_pc = {i_r_data, tmpr[7:0]};
                        next_sp = sp + 16'd1;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_RETI: begin
                    if (mcycle == 8'd1) begin
                        o_address = sp;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_sp = sp + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = sp;
                        o_re = 1;
                        next_pc = {i_r_data, tmpr[7:0]};
                        next_sp = sp + 16'd1;
                        next_ime = 1;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_JP_COND: begin
                    // JP cc, imm16
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = pc;
                        o_re = 1;
                        // 条件成立ならPCをジャンプ先へ
                        if (((opcode[4:3] == COND_NZ) && (!flags[FLAG_Z]))
                            || ((opcode[4:3] == COND_Z) && (flags[FLAG_Z]))
                            || ((opcode[4:3] == COND_NC) && (!flags[FLAG_C]))
                            || ((opcode[4:3] == COND_C) && (flags[FLAG_C]))) begin
                            next_pc = {i_r_data, tmpr[7:0]};
                            next_mcycle = 8'd3;
                        end else begin
                            // 条件不成立ならばここで終わり
                            next_pc = pc + 16'd1;
                            next_mcycle = 8'd0;
                        end
                    end else if (mcycle == 8'd3) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_JP: begin
                    // JP imm16
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = pc;
                        o_re = 1;
                        next_pc = {i_r_data, tmpr[7:0]};
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_CALL_COND: begin
                    // CALL cc, imm16
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        if (((opcode[4:3] == COND_NZ) && (!flags[FLAG_Z]))
                            || ((opcode[4:3] == COND_Z) && (flags[FLAG_Z]))
                            || ((opcode[4:3] == COND_NC) && (!flags[FLAG_C]))
                            || ((opcode[4:3] == COND_C) && (flags[FLAG_C]))) begin
                            o_address = pc;
                            o_re = 1;
                            next_tmpr = {i_r_data, tmpr[7:0]};
                            next_mcycle = 8'd3;
                        end else begin
                            next_mcycle = 8'd0;
                        end
                        next_pc = pc + 16'd1;
                    end else if (mcycle == 8'd3) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        o_w_data = pc[15:8];
                        next_sp = sp - 16'd1;
                        next_mcycle = 8'd4;
                    end else if (mcycle == 8'd4) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        o_w_data = pc[7:0];
                        next_sp = sp - 16'd1;
                        next_pc = tmpr;
                        next_mcycle = 8'd5;
                    end else if (mcycle == 8'd5) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_CALL: begin
                    // CALL imm16
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = pc;
                        o_re = 1;
                        next_tmpr = {i_r_data, tmpr[7:0]};
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        o_w_data = pc[15:8];
                        next_sp = sp - 16'd1;
                        next_mcycle = 8'd4;
                    end else if (mcycle == 8'd4) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        o_w_data = pc[7:0];
                        next_sp = sp - 16'd1;
                        next_pc = tmpr;
                        next_mcycle = 8'd5;
                    end else if (mcycle == 8'd5) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_RST: begin
                    // RST
                    if (mcycle == 8'd1) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        o_w_data = pc[15:8];
                        next_sp = sp - 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        o_w_data = pc[7:0];
                        next_sp = sp - 16'd1;
                        next_pc = {10'd0, opcode[5:3], 3'b000};
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_POP: begin
                    // POP
                    if (mcycle == 8'd1) begin
                        o_address = sp;
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_sp = sp + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = sp;
                        o_re = 1;
                        r16_w_data = {i_r_data, tmpr[7:0]};
                        r16_dst = opcode[5:4];
                        r16stk_we = 1;
                        next_sp = sp + 16'd1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_PUSH: begin
                    // PUSH
                    if (mcycle == 8'd1) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        case (opcode[5:4]) 
                            R16STK_BC: o_w_data = b;
                            R16STK_DE: o_w_data = d;
                            R16STK_HL: o_w_data = h;
                            R16STK_AF: o_w_data = a;
                        endcase
                        next_sp = sp - 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        o_address = sp - 16'd1;
                        o_we = 1;
                        case (opcode[5:4]) 
                            R16STK_BC: o_w_data = c;
                            R16STK_DE: o_w_data = e;
                            R16STK_HL: o_w_data = l;
                            R16STK_AF: o_w_data = flags;
                        endcase
                        next_sp = sp - 16'd1;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        // NOTE: 既に処理は終わっているがサイクルを合わせる
                        next_mcycle = 8'd0;
                    end
                end
                OP_PREFIX: begin
                    // PREFIX命令のデコード
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        next_op = decode_prefix_opcode(i_r_data);
                        next_opcode = fetch_opcode;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd2;
                        // プレフィックス命令のうち命令デコードと同時に実行する命令
                        case (next_op)
                            OP_RLC: begin
                                // RLC
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {next_tmpr[6:0], next_tmpr[7]};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = next_tmpr[7];
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_RRC: begin
                                // RRC
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {next_tmpr[0], next_tmpr[7:1]};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = next_tmpr[0];
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_RL: begin
                                // RL
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {next_tmpr[6:0], flags[FLAG_C]};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = next_tmpr[7];
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_RR: begin
                                // RR
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {flags[FLAG_C], next_tmpr[7:1]};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = next_tmpr[0];
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_SLA: begin
                                // SLA
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {next_tmpr[6:0], 1'b0};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = next_tmpr[7];
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_SRA: begin
                                // SRA
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {next_tmpr[7], next_tmpr[7:1]};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = next_tmpr[0];
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_SWAP: begin
                                // SWAP
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {next_tmpr[3:0], next_tmpr[7:4]};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = 0;
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_SRL: begin
                                // SRL
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = {1'b0, next_tmpr[7:1]};
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_flags[FLAG_Z] = (r8_w_data == 0);
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 0;
                                    next_flags[FLAG_C] = next_tmpr[0];
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_BIT: begin
                                // BIT
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    next_flags[FLAG_Z] = ~next_tmpr[{1'b0, fetch_opcode[5:3]}];
                                    next_flags[FLAG_N] = 0;
                                    next_flags[FLAG_H] = 1;
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_RES: begin
                                // RES
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = next_tmpr[7:0] & ~(8'd1 << fetch_opcode[5:3]);
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_mcycle = 8'd0;
                                end
                            end
                            OP_SET: begin
                                // SET
                                if (fetch_opcode[2:0] != R8_HL_INDIRECT) begin
                                    next_tmpr[7:0] = get_r8(fetch_opcode[2:0]);
                                    r8_w_data = next_tmpr[7:0] | (8'd1 << fetch_opcode[5:3]);
                                    r8_dst = fetch_opcode[2:0];
                                    r8_we = 1;
                                    next_mcycle = 8'd0;
                                end
                            end
                            default: begin
                                // 何もしない
                            end
                        endcase
                    end
                end
                OP_LDH: begin
                    if (opcode[4]) begin
                        // LDH A, [C]
                        if (mcycle == 8'd1) begin
                            o_address = {8'hFF, c};
                            o_re = 1;
                            r8_w_data = i_r_data;
                            r8_dst = R8_A;
                            r8_we = 1;
                            next_mcycle = 8'd0;
                        end
                    end else begin
                        // LDH [C], A
                        if (mcycle == 8'd1) begin
                            o_address = {8'hFF, c};
                            o_we = 1;
                            o_w_data = a;
                            next_mcycle = 8'd0;
                        end
                    end
                end
                OP_LDH_IMM8: begin
                    if (opcode[4]) begin
                        // LDH A, [imm8]
                        if (mcycle == 8'd1) begin
                            o_address = pc;
                            o_re = 1;
                            next_tmpr[7:0] = i_r_data;
                            next_pc = pc + 16'd1;
                            next_mcycle = 8'd2;
                        end else if (mcycle == 8'd2) begin
                            o_address = {8'hFF, tmpr[7:0]};
                            o_re = 1;
                            r8_w_data = i_r_data;
                            r8_dst = R8_A;
                            r8_we = 1;
                            next_mcycle = 8'd0;
                        end
                    end else begin
                        // LDH [imm8], A
                        if (mcycle == 8'd1) begin
                            o_address = pc;
                            o_re = 1;
                            next_tmpr[7:0] = i_r_data;
                            next_pc = pc + 16'd1;
                            next_mcycle = 8'd2;
                        end else if (mcycle == 8'd2) begin
                            o_address = {8'hFF, tmpr[7:0]};
                            o_we = 1;
                            o_w_data = a;
                            next_mcycle = 8'd0;
                        end
                    end
                end
                OP_LD_IMM16_DIRECT: begin
                    if (opcode[4]) begin
                        // LD A, [imm16]
                        if (mcycle == 8'd1) begin
                            o_address = pc;
                            o_re = 1;
                            next_tmpr[7:0] = i_r_data;
                            next_pc = pc + 16'd1;
                            next_mcycle = 8'd2;
                        end else if (mcycle == 8'd2) begin
                            o_address = pc;
                            o_re = 1;
                            next_tmpr = {i_r_data, tmpr[7:0]};
                            next_pc = pc + 16'd1;
                            next_mcycle = 8'd3;
                        end else if (mcycle == 8'd3) begin
                            o_address = tmpr;
                            o_re = 1;
                            r8_w_data = i_r_data;
                            r8_dst = R8_A;
                            r8_we = 1;
                            next_mcycle = 8'd0;
                        end
                    end else begin
                        // LD [imm16], A
                        if (mcycle == 8'd1) begin
                            o_address = pc;
                            o_re = 1;
                            next_tmpr[7:0] = i_r_data;
                            next_pc = pc + 16'd1;
                            next_mcycle = 8'd2;
                        end else if (mcycle == 8'd2) begin
                            o_address = pc;
                            o_re = 1;
                            next_tmpr = {i_r_data, tmpr[7:0]};
                            next_pc = pc + 16'd1;
                            next_mcycle = 8'd3;
                        end else if (mcycle == 8'd3) begin
                            o_address = tmpr;
                            o_we = 1;
                            o_w_data = a;
                            next_mcycle = 8'd0;
                        end
                    end
                end
                OP_ADD_SP: begin
                    // ADD SP, emm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        // 符号拡張して符号付き加算
                        next_tmpr = {{8{i_r_data[7]}}, i_r_data};
                        next_sp = sp + $signed(next_tmpr);
                        // キャリーの判定は8bitの範囲で行う
                        next_flags[FLAG_H] = (((sp ^ next_tmpr ^ next_pc) & 16'h10) == 16'h10);
                        next_flags[FLAG_C] = (((sp ^ next_tmpr ^ next_pc) & 16'h100) == 16'h100);
                        next_flags[FLAG_Z] = 0;
                        next_flags[FLAG_N] = 0;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        // NOTE: 何もしない。サイクル数を揃える
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        // NOTE: 何もしない。サイクル数を揃える
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD_HL_SP_IMM8: begin
                    // LD HL, SP + emm8
                    if (mcycle == 8'd1) begin
                        o_address = pc;
                        o_re = 1;
                        // 符号拡張して符号付き加算
                        next_tmpr = {{8{i_r_data[7]}}, i_r_data};
                        r16_w_data = sp + $signed(next_tmpr);
                        r16_dst = R16_HL;
                        r16_we = 1;
                        // キャリーの判定は8bitの範囲で行う
                        next_flags[FLAG_H] = (((sp ^ next_tmpr ^ r16_w_data) & 16'h10) == 16'h10);
                        next_flags[FLAG_C] = (((sp ^ next_tmpr ^ r16_w_data) & 16'h100) == 16'h100);
                        next_flags[FLAG_Z] = 0;
                        next_flags[FLAG_N] = 0;
                        next_pc = pc + 16'd1;
                        next_mcycle = 8'd2;
                    end else if (mcycle == 8'd2) begin
                        // NOTE: 何もしない。サイクル数を揃える
                        next_mcycle = 8'd0;
                    end
                end
                OP_LD_SP_HL: begin
                    // LD SP, HL
                    if (mcycle == 8'd1) begin
                        next_mcycle = 8'd0; // NOTE: 1サイクル目で処理は終わっている
                    end
                end
                OP_RLC: begin
                    // RLC [HL]
                    // NOTE: RLC r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {i_r_data[6:0], i_r_data[7]};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = i_r_data[7];
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_RRC: begin
                    // RRC [HL]
                    // NOTE: RRC r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {i_r_data[0], i_r_data[7:1]};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = i_r_data[0];
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_RL: begin
                    // RL [HL]
                    // NOTE: RL r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {i_r_data[6:0], flags[FLAG_C]};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = i_r_data[7];
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_RR: begin
                    // RR [HL]
                    // NOTE: RR r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {flags[FLAG_C], i_r_data[7:1]};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = i_r_data[0];
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_SLA: begin
                    // SLA [HL]
                    // NOTE: SLA r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {i_r_data[6:0], 1'b0};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = i_r_data[7];
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_SRA: begin
                    // SRA [HL]
                    // NOTE: SRA r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {i_r_data[7], i_r_data[7:1]};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = i_r_data[0];
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_SWAP: begin
                    // SWAP [HL]
                    // NOTE: SWAP r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {i_r_data[3:0], i_r_data[7:4]};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = 0;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_SRL: begin
                    // SRL [HL]
                    // NOTE: SRL r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = {1'b0, i_r_data[7:1]};
                        next_flags[FLAG_Z] = (next_tmpr == 0);
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 0;
                        next_flags[FLAG_C] = i_r_data[0];
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0];
                        next_mcycle = 8'd0;
                    end
                end
                OP_BIT: begin
                    // BIT [HL]
                    // NOTE: BIT r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_flags[FLAG_Z] = ~i_r_data[opcode[5:3]];
                        next_flags[FLAG_N] = 0;
                        next_flags[FLAG_H] = 1;
                        next_mcycle = 8'd0;
                    end
                end
                OP_RES: begin
                    // RES [HL]
                    // NOTE: RES r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0] & ~(8'd1 << opcode[5:3]);
                        next_mcycle = 8'd0;
                    end
                end
                OP_SET: begin
                    // SET [HL]
                    // NOTE: SET r8は2サイクル目で終わっている
                    if (mcycle == 8'd2) begin
                        o_address = get_r16(R16_HL);
                        o_re = 1;
                        next_tmpr[7:0] = i_r_data;
                        next_mcycle = 8'd3;
                    end else if (mcycle == 8'd3) begin
                        o_address = get_r16(R16_HL);
                        o_we = 1;
                        o_w_data = tmpr[7:0] | (8'd1 << opcode[5:3]);
                        next_mcycle = 8'd0;
                    end
                end
                default: begin
                    // TODO: 未実装。PCを止める
                    next_pc = pc;
                end
            endcase
        end
    end

endmodule
