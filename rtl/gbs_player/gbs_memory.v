`timescale 1ns/1ns
`include "sm83_register_address.vh"

module gbs_memory #(
    parameter ROM_FILE = "", // 初期ROMファイル
    parameter ROM_ADDRESS_BITS = 22, // ROMアドレスビット幅
    parameter ROM_SIZE = (1 << ROM_ADDRESS_BITS)  // ROMメモリサイズ
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire [15:0] i_address, // 読み書きアドレス
    input wire [7:0] i_w_data, // 書き込みデータ
    input wire i_re, // メモリ読み出しイネーブル
    input wire i_we, // メモリ書き出しイネーブル
    output reg [7:0] o_r_data // 読み込みデータ
);
    // ROM終端アドレス
    localparam ROM_END_ADDRESS = `VRAM_START_ADDRESS;

    reg [7:0] ram[0:32767]; // RAM(32KiB)
    reg [7:0] rom[0:ROM_SIZE - 1]; // ROM
    reg [7:0] rom_bank; // ROMバンク番号
    reg [3:0] ramg; // RAMG

    // レジスタ書き込み
    wire ramg_write = i_we & (i_address < `BANK1_START_ADDRESS);
    wire bank1_low_write = i_we & (i_address >= `BANK1_START_ADDRESS) & (i_address < `BANK2_START_ADDRESS);
    wire bank1_high_write = i_we & (i_address >= `BANK2_START_ADDRESS) & (i_address < `MODE_START_ADDRESS);
    wire ext_ram_write = i_we & (ramg == 4'hA) & (i_address >= `EXTERNAL_RAM_START_ADDRESS) & (i_address < `WRAM_BANK0_START_ADDRESS);
    wire ram_write = i_we & (i_address >= `WRAM_BANK0_START_ADDRESS) & (i_address < `ECHO_RAM_START_ADDRESS);

    // RAM/ROMアドレス
    wire [14:0] ram_address = i_address[14:0] - ROM_END_ADDRESS[14:0];
    wire [21:0] rom_address = (i_address < `ROM_BANK1_START_ADDRESS) ? {6'd0, i_address} : {rom_bank, i_address[13:0]};

    // メモリ初期化
    initial begin
        $readmemh(ROM_FILE, rom);
        $readmemh("testdata/sm83/initial_ram.hex", ram);
    end

    // RAM
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            // 何もしない
        end else if (ext_ram_write | ram_write) begin
            ram[ram_address] <= i_w_data;
        end
    end

    // RAMGとROMバンク
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            ramg <= 4'hA;
            rom_bank <= 8'd1;
        end else if (ramg_write) begin
            ramg <= i_w_data[3:0];
        end else if (bank1_low_write) begin
            rom_bank <= (i_w_data == 0) ? {rom_bank[7:5], 5'd1} : {rom_bank[7:5], i_w_data[4:0]};
        end else if (bank1_high_write) begin
            rom_bank <= {i_w_data[2:0], rom_bank[4:0]};
        end
    end

    // メモリ読み取り
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_r_data <= 8'd0;
        end else if (i_re) begin
            if (i_address < ROM_END_ADDRESS) begin
                o_r_data <= rom[rom_address];
            end else begin
                o_r_data <= ram[ram_address];
            end
        end 
    end

endmodule
