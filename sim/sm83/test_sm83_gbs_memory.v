`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_sm83_gbs_memory;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg we;
    reg re;
    reg [15:0] address;
    reg [7:0] w_data;
    wire [7:0] r_data;

    sm83_gbs_memory memory (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_address(address),
        .i_w_data(w_data),
        .i_re(re),
        .i_we(we),
        .o_r_data(r_data)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

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
    task automatic sm83_gbs_memory_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            `ASSERT_EQ(memory.ramg, 4'hA);
            `ASSERT_EQ(memory.rom_bank, 1);
        end
    endtask

    // メモリ書き込み
    task automatic sm83_gbs_memory_write;
        input reg [15:0] in_address;
        input reg [7:0] value;

        begin
            address = in_address;
            w_data = value;
            we = 1;
            @(posedge clk);
            @(negedge clk);
            we = 0;
        end
    endtask

    // メモリ読み出し
    task automatic sm83_gbs_memory_read;
        input reg [15:0] in_address;
        output reg [7:0] value;

        begin
            address = in_address;
            re = 1;
            @(posedge clk);
            @(negedge clk);
            re = 0;
            value = r_data;
        end
    endtask

    // レジスタ書き込みテスト
    task automatic sm83_gbs_memory_write_registers;
        begin
            sm83_gbs_memory_reset();
            
            sm83_gbs_memory_write(`BANK1_START_ADDRESS - 16'h0001, 8'h0A);
            `EXPECT_EQ(memory.ramg, 4'hA);
            sm83_gbs_memory_write(`BANK1_START_ADDRESS, 8'h00);
            `EXPECT_EQ(memory.rom_bank, 8'h01); // 0を書き込んでも1になる
            sm83_gbs_memory_write(`BANK1_START_ADDRESS, 8'h01);
            `EXPECT_EQ(memory.rom_bank, 8'h01);
            sm83_gbs_memory_write(`BANK2_START_ADDRESS, 8'h01);
            `EXPECT_EQ(memory.rom_bank, 8'h21);
        end
    endtask

    // RAM読み書きテスト
    task automatic sm83_gbs_memory_ram_read_write_test;
        localparam iteration = 1000;
        integer i;
        /* verilator lint_off UNUSEDSIGNAL */
        reg [15:0] io_address;
        /* verilator lint_on UNUSEDSIGNAL */
        reg [7:0] value;
        reg [7:0] rdata;

        begin
            sm83_gbs_memory_reset();

            for (i = 0; i < iteration; i = i + 1) begin
                random16(io_address);
                random8(value);

                // ランダムに書き込む
                address = {2'd0, io_address[13:0]} + `EXTERNAL_RAM_START_ADDRESS;
                sm83_gbs_memory_write(address, value);

                // 同アドレスから読み込む
                sm83_gbs_memory_read(address, rdata);
                `EXPECT_EQ(r_data, rdata);
            end
        end
    endtask

    // ROM読みテスト
    task automatic sm83_gbs_memory_rom_read_test;
        localparam iteration = 1000;
        integer i;
        /* verilator lint_off UNUSEDSIGNAL */
        reg [15:0] io_address;
        /* verilator lint_on UNUSEDSIGNAL */
        reg [7:0] bank;
        reg [7:0] value;
        reg [7:0] rdata;

        begin
            sm83_gbs_memory_reset();

            for (i = 0; i < iteration; i = i + 1) begin
                random16(io_address);
                random8(bank);
                random8(value);

                // ROMバンク設定
                sm83_gbs_memory_write(`BANK1_START_ADDRESS, {3'd0, bank[4:0]});
                sm83_gbs_memory_write(`BANK2_START_ADDRESS, {bank[7:5], 5'd0});

                // ランダムに書き込む
                address = {1'd0, io_address[14:0]};
                @(posedge clk);
                memory.rom[memory.rom_address] = value;

                // 同アドレスから読み込む
                sm83_gbs_memory_read(address, rdata);
                `EXPECT_EQ(rdata, value);
            end
        end
    endtask

    initial begin
        $dumpfile("build/test_sm83_gbs_memory.vcd");
        $dumpvars(0, test_sm83_gbs_memory);

        clk = 0;

        sm83_gbs_memory_write_registers();
        sm83_gbs_memory_ram_read_write_test();
        sm83_gbs_memory_rom_read_test();
            
        $finish;
    end
    
endmodule
