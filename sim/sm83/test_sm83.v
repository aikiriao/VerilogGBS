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

        $finish;
    end
endmodule
