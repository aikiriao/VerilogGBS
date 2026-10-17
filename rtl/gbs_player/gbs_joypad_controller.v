`timescale 1ns/1ns
`include "sm83_register_address.vh"

module gbs_joypad_controller (
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_register, // レジスタ書き込みイネーブル
    input wire [15:0] i_address, // アドレス
    input wire [7:0] i_w_data, // 書き込みデータ
    input wire i_we_command, // コマンド書き込みイネーブル
    input wire [7:0] i_command, // コマンド入力
    output reg [7:0] o_r_data, // 読み込みデータ
    output wire o_joypad_irq // ジョイパッド割り込み
);
    `include "gbs_player_joypad_command.vh"

    // 各レジスタの書き込み信号
    wire joypad_write = i_we_register & (i_address == `HWREG_P1_JOYPAD);
    wire num_songs_write = i_we_register & (i_address == `HWREG_GBS_NUMBER_OF_SONGS);
    wire current_song_write = i_we_register & (i_address == `HWREG_GBS_CURRENT_SONG_NUMBER);

    // 有効なコマンドか？
    wire command_valid = (i_command == JOYPAD_COMMAND_NEXT_SONG) || (i_command == JOYPAD_COMMAND_PREV_SONG);

    // レジスタ
    reg [7:0] joypad_input; // ジョイパッド入力
    reg [7:0] num_songs; // 楽曲数
    reg [7:0] song_number; // 楽曲番号

    // レジスタ読み取り
    always @(*) begin
        case (i_address)
            `HWREG_P1_JOYPAD:
                o_r_data = joypad_input;
            `HWREG_GBS_NUMBER_OF_SONGS:
                o_r_data = num_songs;
            `HWREG_GBS_CURRENT_SONG_NUMBER:
                o_r_data = song_number;
            default:
                o_r_data = 8'h00;
        endcase
    end

    // ジョイパッド入力更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            joypad_input <= 8'd0;
        end else if (joypad_write) begin
            joypad_input <= i_w_data;
        end
    end

    // 楽曲数更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            num_songs <= 8'd0;
        end else if (num_songs_write) begin
            num_songs <= i_w_data;
        end
    end

    // 楽曲番号更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            song_number <= 8'd0;
        end else if (current_song_write) begin
            song_number <= i_w_data;
        end else if (i_we_command) begin
            case (i_command) 
                JOYPAD_COMMAND_NEXT_SONG:
                    song_number <= (song_number >= (num_songs - 8'd1)) ? (num_songs - 8'd1) : (song_number + 8'd1);
                JOYPAD_COMMAND_PREV_SONG:
                    song_number <= (song_number == 8'd0) ? 8'd0 : (song_number - 8'd1);
                default: ; // 何もしない
            endcase
        end
    end

    // ジョイパッド割り込み生成
    assign o_joypad_irq = i_we_command & command_valid;

endmodule
