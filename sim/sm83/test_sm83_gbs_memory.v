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

    // リセットタスク
    task automatic sm83_gbs_memory_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            `ASSERT_EQ(memory.ramg, 0);
            `ASSERT_EQ(memory.rom_bank, 0);
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
            value = r_data;
            re = 1;
            @(posedge clk);
            @(negedge clk);
            re = 0;
        end
    endtask

    initial begin
        $dumpfile("build/test_sm83_gbs_memory.vcd");
        $dumpvars(0, test_sm83_gbs_memory);

        $readmemh("./testdata/sm83/pkred_rom.hex", memory.rom);

        clk = 0;
        sm83_gbs_memory_reset();
            
        $finish;
    end
    
endmodule
