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
localparam R16MEM_HL_DEC = 2'd3;

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
localparam OP_LD_A_TO_INDIRECT = 8'd1;
localparam OP_LD_INDIRECT_TO_A = 8'd2;
localparam OP_LD16_IMM16 = 8'd3;
localparam OP_LD16_SP_TO_IMM16_DIRECT = 8'd4;
localparam OP_INC16 = 8'd5;
localparam OP_DEC16 = 8'd6;
localparam OP_ADD16 = 8'd7;
localparam OP_INC = 8'd8;
localparam OP_DEC = 8'd9;
localparam OP_RLCA = 8'd10;
localparam OP_RRCA = 8'd11;
localparam OP_RLA = 8'd12;
localparam OP_RRA = 8'd13;
localparam OP_DAA = 8'd14;
localparam OP_CPL = 8'd15;
localparam OP_SCF = 8'd16;
localparam OP_CCF = 8'd17;
localparam OP_JR_NOCOND = 8'd18;
localparam OP_JR = 8'd19;
localparam OP_STOP = 8'd20;
localparam OP_LD = 8'd21;
localparam OP_LD_IMM8 = 8'd22;
localparam OP_HALT = 8'd23;
localparam OP_ADD = 8'd24;
localparam OP_ADC = 8'd25;
localparam OP_SUB = 8'd26;
localparam OP_SBC = 8'd27;
localparam OP_AND = 8'd28;
localparam OP_XOR = 8'd29;
localparam OP_OR = 8'd30;
localparam OP_CP = 8'd31;
localparam OP_ADD_IMM8 = 8'd32;
localparam OP_ADC_IMM8 = 8'd33;
localparam OP_SUB_IMM8 = 8'd34;
localparam OP_SBC_IMM8 = 8'd35;
localparam OP_AND_IMM8 = 8'd36;
localparam OP_XOR_IMM8 = 8'd37;
localparam OP_OR_IMM8 = 8'd38;
localparam OP_CP_IMM8 = 8'd39;
localparam OP_RET_COND = 8'd40;
localparam OP_RET = 8'd41;
localparam OP_RETI = 8'd42;
localparam OP_JP_COND = 8'd43;
localparam OP_JP = 8'd44;
localparam OP_JP_HL = 8'd45;
localparam OP_CALL_COND = 8'd46;
localparam OP_CALL = 8'd47;
localparam OP_RST = 8'd48;
localparam OP_POP = 8'd49;
localparam OP_PUSH = 8'd50;
localparam OP_PREFIX = 8'd51; // 0xCB prefix code
localparam OP_LDH = 8'd52;
localparam OP_LDH_IMM8 = 8'd53;
localparam OP_LD_IMM16_DIRECT = 8'd54;
localparam OP_ADD_SP = 8'd55;
localparam OP_LD_HL_SP_IMM8 = 8'd56;
localparam OP_LD_SP_HL = 8'd57;
localparam OP_DI = 8'd58;
localparam OP_EI = 8'd59;

// プレフィックス命令
localparam OP_RLC = 8'd60;
localparam OP_RRC = 8'd61;
localparam OP_RL = 8'd62;
localparam OP_RR = 8'd63;
localparam OP_SLA = 8'd64;
localparam OP_SRA = 8'd65;
localparam OP_SWAP = 8'd66;
localparam OP_SRL = 8'd67;
localparam OP_BIT = 8'd68;
localparam OP_RES = 8'd69;
localparam OP_SET = 8'd70;
