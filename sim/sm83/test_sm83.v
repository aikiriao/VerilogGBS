`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_sm83;
    parameter STEP = 10;

    `include "sm83_defs.vh"

    reg clk;
    reg rst_n;
    reg [7:0] memory[0:65535];
    wire [7:0] r_data;
    wire [15:0] address;
    wire [7:0] w_data;
    wire re;
    wire we;
    integer i;

    sm83 cpu (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_r_data(r_data),
        .o_address(address),
        .o_w_data(w_data),
        .o_re(re),
        .o_we(we)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    // メモリ
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 65536; i = i + 1) begin
                memory[i] <= 0;
            end
        end else if (we) begin
            memory[address] <= w_data;
        end
    end
    assign r_data = (re) ? memory[address] : 8'd0;

    // 8bitの乱数生成
    /* verilator lint_off UNUSEDSIGNAL */
    task automatic random8;
        output reg [7:0] r8;
        reg [31:0] r;
        begin
            r = $random;
            r8 = r[7:0];
        end
    endtask
    /* verilator lint_on UNUSEDSIGNAL */

    // 16bitの乱数生成
    task automatic random16;
        output reg [15:0] r16;
        begin
            random8(r16[15:8]);
            random8(r16[7:0]);
        end
    endtask

    // リセットタスク
    task automatic sm83_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            for (i = 0; i < 8; i = i + 1) begin
                `ASSERT_EQ(cpu.r8[i], 0);
            end
            `ASSERT_EQ(cpu.flags, 0);
            `ASSERT_EQ(cpu.sp, 0);
            `ASSERT_EQ(cpu.pc, 0);
            `ASSERT_EQ(cpu.mcycle, 0);
            `ASSERT_EQ(cpu.opcode, 0);
            `ASSERT_EQ(cpu.r8_dst, 0);
            `ASSERT_EQ(cpu.r8_we, 0);
            `ASSERT_EQ(cpu.r8_w_data, 0);
            `ASSERT_EQ(cpu.tmpr, 0);
            `ASSERT_EQ(cpu.next_mcycle, 1); // NOPが読み込まれて1進む
            `ASSERT_EQ(cpu.next_opcode, 0);
            `ASSERT_EQ(cpu.next_pc, 1); // NOPが読み込まれて1進む
            `ASSERT_EQ(cpu.next_flags, 0);
            `ASSERT_EQ(cpu.next_sp, 0);
            `ASSERT_EQ(cpu.next_tmpr, 0);
        end
    endtask

    // NOP命令のテスト
    task automatic sm83_nop_test;
        begin
            sm83_reset();

            memory[0] = 8'h00;
            memory[1] = 8'h00;

            // 1クロック進める
            @(posedge clk);
            @(negedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                `EXPECT_EQ(cpu.r8[i], 0);
            end
            `EXPECT_EQ(cpu.flags, 0);
            `EXPECT_EQ(cpu.sp, 0);
            `EXPECT_EQ(cpu.pc, 1); // PCは1進む
            `EXPECT_EQ(cpu.mcycle, 1);
            `EXPECT_EQ(cpu.opcode, 0);
            `EXPECT_EQ(cpu.r8_dst, 0);
            `EXPECT_EQ(cpu.r8_we, 0);
            `EXPECT_EQ(cpu.r8_w_data, 0);
            `EXPECT_EQ(cpu.tmpr, 0);
            `EXPECT_EQ(cpu.next_mcycle, 0);
            `EXPECT_EQ(cpu.next_opcode, 0);
            `EXPECT_EQ(cpu.next_pc, 1); // 1進んだ状態で止まる
            `EXPECT_EQ(cpu.next_flags, 0);
            `EXPECT_EQ(cpu.next_sp, 0);
            `EXPECT_EQ(cpu.next_tmpr, 0);
        end
    endtask

    // LD r16, imm16のテスト
    task automatic sm83_ld16_imm16_test_sub;
        input reg [1:0] dst;
        integer c;
        reg [15:0] imm16;
        localparam iteration = 10;

        begin
            for (c = 0; c < iteration; c = c + 1) begin
                sm83_reset();
                
                // 命令を生成
                memory[0] = {2'b00, dst, 4'b0001};
                // imm16は乱数
                random16(imm16);
                memory[1] = imm16[7:0];
                memory[2] = imm16[15:8];

                // 3クロック進める
                repeat (3) @(posedge clk);
                @(negedge clk);

                `EXPECT_EQ(cpu.pc, 3); // PCは次の3を指す
                case (dst)
                    R16_BC: begin
                        `EXPECT_EQ(cpu.r8[R8_B], imm16[15:8]);
                        `EXPECT_EQ(cpu.r8[R8_C], imm16[7:0]);
                    end
                    R16_DE: begin
                        `EXPECT_EQ(cpu.r8[R8_D], imm16[15:8]);
                        `EXPECT_EQ(cpu.r8[R8_E], imm16[7:0]);
                    end
                    R16_HL: begin
                        `EXPECT_EQ(cpu.r8[R8_H], imm16[15:8]);
                        `EXPECT_EQ(cpu.r8[R8_L], imm16[7:0]);
                    end
                    R16_SP: begin
                        `EXPECT_EQ(cpu.sp, imm16);
                    end
                endcase
            end
        end
    endtask

    // LD r16, imm16のテスト
    task automatic sm83_ld16_imm16_test;
        begin
            sm83_ld16_imm16_test_sub(R16_BC);
            sm83_ld16_imm16_test_sub(R16_DE);
            sm83_ld16_imm16_test_sub(R16_HL);
            sm83_ld16_imm16_test_sub(R16_SP);
        end
    endtask

    // LD a, [imm16]のテスト
    task automatic sm83_ld_a_to_indirect_test_sub;
        input reg [1:0] dst;
        integer c;
        reg [15:0] imm16;
        reg [7:0] imm8;
        localparam iteration = 10;

        begin
            for (c = 0; c < iteration; c = c + 1) begin
                sm83_reset();
                
                // 命令を生成
                memory[0] = {2'b00, dst, 4'b0010};

                // ランダムなアドレスにランダムな値を書き込む
                random8(imm8);
                random16(imm16);
                cpu.r8[R8_A] = imm8; 
                case (dst)
                    R16MEM_BC: begin
                        cpu.r8[R8_B] = imm16[15:8];
                        cpu.r8[R8_C] = imm16[7:0];
                    end
                    R16MEM_DE: begin
                        cpu.r8[R8_D] = imm16[15:8];
                        cpu.r8[R8_E] = imm16[7:0];
                    end
                    R16MEM_HL_INC: begin
                        cpu.r8[R8_H] = imm16[15:8];
                        cpu.r8[R8_L] = imm16[7:0];
                    end
                    R16MEM_HL_DEC: begin
                        cpu.r8[R8_H] = imm16[15:8];
                        cpu.r8[R8_L] = imm16[7:0];
                    end
                endcase

                repeat (2) @(posedge clk);
                @(negedge clk);

                `EXPECT_EQ(cpu.pc, 1); // PCは次の1を指す
                `EXPECT_EQ(memory[imm16], imm8); // 意図された値が書き込まれているか
                if (dst == R16MEM_HL_INC) begin
                    `EXPECT_EQ({cpu.r8[R8_H], cpu.r8[R8_L]}, imm16 + 16'd1);
                end else if (dst == R16MEM_HL_DEC) begin
                    `EXPECT_EQ({cpu.r8[R8_H], cpu.r8[R8_L]}, imm16 - 16'd1);
                end
            end
        end
    endtask

    // LD a, [imm16]のテスト
    task automatic sm83_ld_a_to_indirect_test;
        begin
            sm83_ld_a_to_indirect_test_sub(R16MEM_BC);
            sm83_ld_a_to_indirect_test_sub(R16MEM_DE);
            sm83_ld_a_to_indirect_test_sub(R16MEM_HL_INC);
            sm83_ld_a_to_indirect_test_sub(R16MEM_HL_DEC);
        end
    endtask

    // LD [imm16], aのテスト
    task automatic sm83_ld_indirect_to_a_test_sub;
        input reg [1:0] src;
        integer c;
        reg [15:0] imm16;
        reg [7:0] imm8;
        localparam iteration = 10;

        begin
            for (c = 0; c < iteration; c = c + 1) begin
                sm83_reset();
                
                // 命令を生成
                memory[0] = {2'b00, src, 4'b1010};

                // ランダムなアドレスにランダムな値を書き込む
                random8(imm8);
                random16(imm16);
                memory[imm16] = imm8;
                case (src)
                    R16MEM_BC: begin
                        cpu.r8[R8_B] = imm16[15:8];
                        cpu.r8[R8_C] = imm16[7:0];
                    end
                    R16MEM_DE: begin
                        cpu.r8[R8_D] = imm16[15:8];
                        cpu.r8[R8_E] = imm16[7:0];
                    end
                    R16MEM_HL_INC: begin
                        cpu.r8[R8_H] = imm16[15:8];
                        cpu.r8[R8_L] = imm16[7:0];
                    end
                    R16MEM_HL_DEC: begin
                        cpu.r8[R8_H] = imm16[15:8];
                        cpu.r8[R8_L] = imm16[7:0];
                    end
                endcase

                repeat (2) @(posedge clk);
                @(negedge clk);

                `EXPECT_EQ(cpu.pc, 1); // PCは次の1を指す
                `EXPECT_EQ(cpu.r8[R8_A], imm8); // 意図された値が書き込まれているか
                if (src == R16MEM_HL_INC) begin
                    `EXPECT_EQ({cpu.r8[R8_H], cpu.r8[R8_L]}, imm16 + 16'd1);
                end else if (src == R16MEM_HL_DEC) begin
                    `EXPECT_EQ({cpu.r8[R8_H], cpu.r8[R8_L]}, imm16 - 16'd1);
                end
            end
        end
    endtask

    // LD a, [imm16]のテスト
    task automatic sm83_ld_indirect_to_a_test;
        begin
            sm83_ld_indirect_to_a_test_sub(R16MEM_BC);
            sm83_ld_indirect_to_a_test_sub(R16MEM_DE);
            sm83_ld_indirect_to_a_test_sub(R16MEM_HL_INC);
            sm83_ld_indirect_to_a_test_sub(R16MEM_HL_DEC);
        end
    endtask

    // INC r16のテスト
    task automatic sm83_inc_r16_test_sub;
        input reg [1:0] dst;
        input reg [15:0] initial_r16;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = {2'b00, dst, 4'b0011};
            
            case (dst)
                R16_BC: begin
                    cpu.r8[R8_B] = initial_r16[15:8];
                    cpu.r8[R8_C] = initial_r16[7:0];
                end
                R16_DE: begin
                    cpu.r8[R8_D] = initial_r16[15:8];
                    cpu.r8[R8_E] = initial_r16[7:0];
                end
                R16_HL: begin
                    cpu.r8[R8_H] = initial_r16[15:8];
                    cpu.r8[R8_L] = initial_r16[7:0];
                end
                R16_SP: begin
                    cpu.sp = initial_r16;
                end
            endcase
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1); // PCは次の1を指す
            `EXPECT_EQ(cpu.get_r16(dst), initial_r16 + 16'd1); // 意図された値が書き込まれているか
        end
    endtask

    // INC r16のテスト
    task automatic sm83_inc_r16_test;
        integer r16_dst;

        begin
            // 境界値付近だけ攻める
            for (r16_dst = 0; r16_dst <= 2'd3; r16_dst = r16_dst + 1) begin
                sm83_inc_r16_test_sub(r16_dst[1:0], 16'h0000);
                sm83_inc_r16_test_sub(r16_dst[1:0], 16'h00FF);
                sm83_inc_r16_test_sub(r16_dst[1:0], 16'hFFFF);
            end
        end
    endtask

    // DEC r16のテスト
    task automatic sm83_dec_r16_test_sub;
        input reg [1:0] dst;
        input reg [15:0] initial_r16;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = {2'b00, dst, 4'b1011};
            
            case (dst)
                R16_BC: begin
                    cpu.r8[R8_B] = initial_r16[15:8];
                    cpu.r8[R8_C] = initial_r16[7:0];
                end
                R16_DE: begin
                    cpu.r8[R8_D] = initial_r16[15:8];
                    cpu.r8[R8_E] = initial_r16[7:0];
                end
                R16_HL: begin
                    cpu.r8[R8_H] = initial_r16[15:8];
                    cpu.r8[R8_L] = initial_r16[7:0];
                end
                R16_SP: begin
                    cpu.sp = initial_r16;
                end
            endcase
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1); // PCは次の1を指す
            `EXPECT_EQ(cpu.get_r16(dst), initial_r16 - 16'd1); // 意図された値が書き込まれているか
        end
    endtask

    // DEC r16のテスト
    task automatic sm83_dec_r16_test;
        integer r16_dst;

        begin
            // 境界値付近だけ攻める
            for (r16_dst = 0; r16_dst <= 2'd3; r16_dst = r16_dst + 1) begin
                sm83_inc_r16_test_sub(r16_dst[1:0], 16'h0000);
                sm83_inc_r16_test_sub(r16_dst[1:0], 16'h0100);
                sm83_inc_r16_test_sub(r16_dst[1:0], 16'hFFFF);
            end
        end
    endtask

    // ADD HL,r16のテスト
    task automatic sm83_add16_test_sub;
        input reg [1:0] src;
        input reg [15:0] src_v;
        input reg [15:0] hl_v;
        input reg carry;
        input reg expected_zero;
        input reg expected_half_carry;
        input reg expected_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = {2'b00, src, 4'b1001};
            
            case (src)
                R16_BC: begin
                    cpu.r8[R8_B] = src_v[15:8];
                    cpu.r8[R8_C] = src_v[7:0];
                end
                R16_DE: begin
                    cpu.r8[R8_D] = src_v[15:8];
                    cpu.r8[R8_E] = src_v[7:0];
                end
                R16_HL: begin
                    `ASSERT_EQ(src_v, hl_v);
                    cpu.r8[R8_H] = src_v[15:8];
                    cpu.r8[R8_L] = src_v[7:0];
                end
                R16_SP: begin
                    cpu.sp = src_v;
                end
            endcase

            // HLレジスタ・キャリーフラグのセット
            cpu.r8[R8_H] = hl_v[15:8];
            cpu.r8[R8_L] = hl_v[7:0];
            cpu.flags[FLAG_C] = carry;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.get_r16(R16_HL), src_v + hl_v + carry);
            `EXPECT_EQ(cpu.flags[FLAG_Z], expected_zero);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.flags[FLAG_H], expected_half_carry);
            `EXPECT_EQ(cpu.flags[FLAG_C], expected_carry);
        end
    endtask

    // ADD HL,r16のテスト
    task automatic sm83_add16_test;
        integer r16_src;

        begin
            // 境界値付近だけ攻める
            for (r16_src = 0; r16_src <= 2'd3; r16_src = r16_src + 1) begin
                if (r16_src[1:0] !== R16_HL) begin
                    sm83_add16_test_sub(r16_src[1:0], 16'h0000, 16'h0000, 0, 1, 0, 0);
                    sm83_add16_test_sub(r16_src[1:0], 16'h0000, 16'h0000, 1, 0, 0, 0);
                    sm83_add16_test_sub(r16_src[1:0], 16'h00FF, 16'h0001, 0, 0, 0, 0);
                    sm83_add16_test_sub(r16_src[1:0], 16'h00FF, 16'h0000, 1, 0, 0, 0);
                    sm83_add16_test_sub(r16_src[1:0], 16'hFFFF, 16'h0000, 0, 0, 0, 0);
                    sm83_add16_test_sub(r16_src[1:0], 16'hFFFF, 16'h0000, 1, 1, 1, 1);
                    sm83_add16_test_sub(r16_src[1:0], 16'hFFFF, 16'h0001, 0, 1, 1, 1);
                end
            end
            sm83_add16_test_sub(R16_HL, 16'h0000, 16'h0000, 0, 1, 0, 0);
            sm83_add16_test_sub(R16_HL, 16'h0000, 16'h0000, 1, 0, 0, 0);
            sm83_add16_test_sub(R16_HL, 16'h0100, 16'h0100, 0, 0, 0, 0);
            sm83_add16_test_sub(R16_HL, 16'h0100, 16'h0100, 1, 0, 0, 0);
            sm83_add16_test_sub(R16_HL, 16'hFFFF, 16'hFFFF, 0, 0, 1, 1);
            sm83_add16_test_sub(R16_HL, 16'hFFFF, 16'hFFFF, 1, 0, 1, 1);
        end
    endtask

    // INC r8のテスト
    task automatic sm83_inc_r8_test_sub;
        input reg [2:0] dst;
        input reg [7:0] initial_value;
        input reg expected_zero;
        input reg expected_half_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = {2'b00, dst, 3'b100};
            // レジスタに初期値をセット
            cpu.r8[dst] = initial_value;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.r8[dst], initial_value + 8'd1);
            `EXPECT_EQ(cpu.flags[FLAG_Z], expected_zero);
            `EXPECT_EQ(cpu.flags[FLAG_H], expected_half_carry);
        end
    endtask

    // INC r8のテスト
    task automatic sm83_inc_r8_test;
        integer r8_dst;

        begin
            // 境界値付近だけ攻める
            for (r8_dst = 0; r8_dst < 8; r8_dst = r8_dst + 1) begin
                if (r8_dst[2:0] !== R8_HL_INDIRECT) begin
                    sm83_inc_r8_test_sub(r8_dst[2:0], 8'h00, 0, 0);
                    sm83_inc_r8_test_sub(r8_dst[2:0], 8'hFF, 1, 1);
                end
            end
        end
    endtask

    // DEC r8のテスト
    task automatic sm83_dec_r8_test_sub;
        input reg [2:0] dst;
        input reg [7:0] initial_value;
        input reg expected_zero;
        input reg expected_half_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = {2'b00, dst, 3'b101};
            // レジスタに初期値をセット
            cpu.r8[dst] = initial_value;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.flags[FLAG_N], 1);
            `EXPECT_EQ(cpu.r8[dst], initial_value - 8'd1);
            `EXPECT_EQ(cpu.flags[FLAG_Z], expected_zero);
            `EXPECT_EQ(cpu.flags[FLAG_H], expected_half_carry);
        end
    endtask

    // DEC r8のテスト
    task automatic sm83_dec_r8_test;
        integer r8_dst;

        begin
            // 境界値付近だけ攻める
            for (r8_dst = 0; r8_dst < 8; r8_dst = r8_dst + 1) begin
                if (r8_dst[2:0] !== R8_HL_INDIRECT) begin
                    sm83_dec_r8_test_sub(r8_dst[2:0], 8'h00, 0, 1);
                    sm83_dec_r8_test_sub(r8_dst[2:0], 8'h01, 1, 0);
                    sm83_dec_r8_test_sub(r8_dst[2:0], 8'hFF, 0, 0);
                end
            end
        end
    endtask

    // LD r8, imm8のテスト
    task automatic sm83_ld_r8_imm8_test_sub;
        input reg [2:0] dst;
        input reg [7:0] load_value;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = {2'b00, dst, 3'b110};
            memory[1] = load_value;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 2);
            `EXPECT_EQ(cpu.r8[dst], load_value);
        end
    endtask

    // LD r8, imm8のテスト
    task automatic sm83_ld_r8_imm8_test;
        integer r8_dst;

        begin
            // 境界値付近だけ攻める
            for (r8_dst = 0; r8_dst < 8; r8_dst = r8_dst + 1) begin
                if (r8_dst[2:0] !== R8_HL_INDIRECT) begin
                    sm83_ld_r8_imm8_test_sub(r8_dst[2:0], 8'h00);
                    sm83_ld_r8_imm8_test_sub(r8_dst[2:0], 8'h55);
                    sm83_ld_r8_imm8_test_sub(r8_dst[2:0], 8'hFF);
                end
            end
        end
    endtask

    // RLCAのテスト
    task automatic sm83_rlca_test_sub;
        input reg [7:0] initial_value;
        input reg initial_carry;
        input reg [7:0] expected_value;
        input reg expected_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = 8'b00000111;
            cpu.r8[R8_A] = initial_value;
            cpu.flags[FLAG_C] = initial_carry;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.r8[R8_A], expected_value);
            `EXPECT_EQ(cpu.flags[FLAG_C], expected_carry);
            `EXPECT_EQ(cpu.flags[FLAG_Z], 0);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.flags[FLAG_H], 0);
        end
    endtask

    // RLCAのテスト
    task automatic sm83_rlca_test;
        begin
            sm83_rlca_test_sub(8'h00, 0, 8'h00, 0);
            sm83_rlca_test_sub(8'hFF, 0, 8'hFF, 1);
            sm83_rlca_test_sub(8'h55, 0, 8'hAA, 0);
            sm83_rlca_test_sub(8'hAA, 0, 8'h55, 1);
        end
    endtask

    // RRCAのテスト
    task automatic sm83_rrca_test_sub;
        input reg [7:0] initial_value;
        input reg initial_carry;
        input reg [7:0] expected_value;
        input reg expected_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = 8'b00001111;
            cpu.r8[R8_A] = initial_value;
            cpu.flags[FLAG_C] = initial_carry;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.r8[R8_A], expected_value);
            `EXPECT_EQ(cpu.flags[FLAG_C], expected_carry);
            `EXPECT_EQ(cpu.flags[FLAG_Z], 0);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.flags[FLAG_H], 0);
        end
    endtask

    // RRCAのテスト
    task automatic sm83_rrca_test;
        begin
            sm83_rrca_test_sub(8'h00, 0, 8'h00, 0);
            sm83_rrca_test_sub(8'hFF, 0, 8'hFF, 1);
            sm83_rrca_test_sub(8'h55, 0, 8'hAA, 1);
            sm83_rrca_test_sub(8'hAA, 0, 8'h55, 0);
        end
    endtask

    // RLAのテスト
    task automatic sm83_rla_test_sub;
        input reg [7:0] initial_value;
        input reg initial_carry;
        input reg [7:0] expected_value;
        input reg expected_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = 8'b00010111;
            cpu.r8[R8_A] = initial_value;
            cpu.flags[FLAG_C] = initial_carry;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.r8[R8_A], expected_value);
            `EXPECT_EQ(cpu.flags[FLAG_C], expected_carry);
            `EXPECT_EQ(cpu.flags[FLAG_Z], 0);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.flags[FLAG_H], 0);
        end
    endtask

    // RLAのテスト
    task automatic sm83_rla_test;
        begin
            sm83_rla_test_sub(8'h00, 0, 8'h00, 0);
            sm83_rla_test_sub(8'h00, 1, 8'h01, 0);
            sm83_rla_test_sub(8'hFF, 0, 8'hFE, 1);
            sm83_rla_test_sub(8'hFF, 1, 8'hFF, 1);
            sm83_rla_test_sub(8'h55, 0, 8'hAA, 0);
            sm83_rla_test_sub(8'h55, 1, 8'hAB, 0);
            sm83_rla_test_sub(8'hAA, 0, 8'h54, 1);
            sm83_rla_test_sub(8'hAA, 1, 8'h55, 1);
        end
    endtask

    // RRAのテスト
    task automatic sm83_rra_test_sub;
        input reg [7:0] initial_value;
        input reg initial_carry;
        input reg [7:0] expected_value;
        input reg expected_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = 8'b00011111;
            cpu.r8[R8_A] = initial_value;
            cpu.flags[FLAG_C] = initial_carry;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.r8[R8_A], expected_value);
            `EXPECT_EQ(cpu.flags[FLAG_C], expected_carry);
            `EXPECT_EQ(cpu.flags[FLAG_Z], 0);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.flags[FLAG_H], 0);
        end
    endtask

    // RRAのテスト
    task automatic sm83_rra_test;
        begin
            sm83_rra_test_sub(8'h00, 0, 8'h00, 0);
            sm83_rra_test_sub(8'h00, 1, 8'h80, 0);
            sm83_rra_test_sub(8'hFF, 0, 8'h7F, 1);
            sm83_rra_test_sub(8'hFF, 1, 8'hFF, 1);
            sm83_rra_test_sub(8'h55, 0, 8'h2A, 1);
            sm83_rra_test_sub(8'h55, 1, 8'hAA, 1);
            sm83_rra_test_sub(8'hAA, 0, 8'h55, 0);
            sm83_rra_test_sub(8'hAA, 1, 8'hD5, 0);
        end
    endtask

    // CPLのテスト
    task automatic sm83_cpl_test_sub;
        input reg [7:0] initial_value;
        input reg [7:0] expected_value;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = 8'b00101111;
            cpu.r8[R8_A] = initial_value;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.r8[R8_A], expected_value);
            `EXPECT_EQ(cpu.flags[FLAG_N], 1);
            `EXPECT_EQ(cpu.flags[FLAG_H], 1);
        end
    endtask

    // CPLのテスト
    task automatic sm83_cpl_test;
        begin
            sm83_cpl_test_sub(8'h00, 8'hFF);
            sm83_cpl_test_sub(8'hFF, 8'h00);
            sm83_cpl_test_sub(8'h55, 8'hAA);
            sm83_cpl_test_sub(8'hAA, 8'h55);
        end
    endtask

    // SCFのテスト
    task automatic sm83_scf_test_sub;
        input reg initial_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = 8'b00110111;
            cpu.flags[FLAG_C] = initial_carry;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.flags[FLAG_C], 1);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.flags[FLAG_H], 0);
        end
    endtask

    // SCFのテスト
    task automatic sm83_scf_test;
        begin
            sm83_scf_test_sub(0);
            sm83_scf_test_sub(1);
        end
    endtask

    // CCFのテスト
    task automatic sm83_ccf_test_sub;
        input reg initial_carry;

        begin
            sm83_reset();
            
            // 命令を生成
            memory[0] = 8'b00111111;
            cpu.flags[FLAG_C] = initial_carry;
            
            repeat (2) @(posedge clk);
            @(negedge clk);
            
            `EXPECT_EQ(cpu.pc, 1);
            `EXPECT_EQ(cpu.flags[FLAG_C], ~initial_carry);
            `EXPECT_EQ(cpu.flags[FLAG_N], 0);
            `EXPECT_EQ(cpu.flags[FLAG_H], 0);
        end
    endtask

    // CCFのテスト
    task automatic sm83_ccf_test;
        begin
            sm83_ccf_test_sub(0);
            sm83_ccf_test_sub(1);
        end
    endtask

    initial begin
        $dumpfile("build/test_sm83.vcd");
        $dumpvars(0, test_sm83);

        clk = 0;

        sm83_nop_test();
        sm83_ld16_imm16_test();
        sm83_ld_a_to_indirect_test();
        sm83_ld_indirect_to_a_test();
        sm83_inc_r16_test();
        sm83_dec_r16_test();
        sm83_add16_test();
        sm83_inc_r8_test();
        sm83_dec_r8_test();
        sm83_ld_r8_imm8_test();
        sm83_rlca_test();
        sm83_rrca_test();
        sm83_rla_test();
        sm83_rra_test();
        sm83_cpl_test();
        sm83_scf_test();
        sm83_ccf_test();

        $finish;
    end
endmodule
