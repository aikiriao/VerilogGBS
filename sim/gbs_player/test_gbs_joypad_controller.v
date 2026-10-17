`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_gbs_joypad_controller;
    parameter STEP = 10;

    `include "gbs_player_joypad_command.vh"

    reg clk;
    reg rst_n;
    reg we_register;
    reg [15:0] address;
    reg [7:0] w_data;
    reg we_command;
    reg [7:0] command;
    wire [7:0] r_data;
    wire joypad_irq;

    gbs_joypad_controller controller (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we_register(we_register),
        .i_address(address),
        .i_w_data(w_data),
        .i_we_command(we_command),
        .i_command(command),
        .o_r_data(r_data),
        .o_joypad_irq(joypad_irq)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    // リセットタスク
    task automatic gbs_joypad_controller_reset;
        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            `ASSERT_EQ(controller.num_songs, 0);
            `ASSERT_EQ(controller.song_number, 0);
        end
    endtask

    // レジスタ書き込み
    task automatic gbs_joypad_controller_write_register;
        input reg [15:0] in_address;
        input reg [7:0] in_w_data;

        begin
            address = in_address;
            w_data = in_w_data;

            we_register = 1;
            @(posedge clk);
            @(negedge clk);
            we_register = 0;
        end
    endtask

    // レジスタ読み込み
    task automatic gbs_joypad_controller_read_register;
        input reg [15:0] in_address;
        output reg [7:0] out_r_data;

        begin
            address = in_address;
            out_r_data = r_data;
        end
    endtask

    // コマンド書き込み
    task automatic gbs_joypad_controller_write_command;
        input reg [7:0] in_command;

        begin
            command = in_command;

            we_command = 1;
            @(posedge clk);
            @(negedge clk);
            `ASSERT_EQ(joypad_irq, 1); // ジョイパッド割り込みが出るはず
            we_command = 0;
        end
    endtask

    // 楽曲番号変更テスト
    task automatic gbs_joypad_controller_change_song;
        reg [7:0] r_reg;
        begin
            // 楽曲数1のときに変更しても変わらないことをテスト
            gbs_joypad_controller_reset();
            gbs_joypad_controller_write_register(`HWREG_GBS_NUMBER_OF_SONGS, 8'd1);
            gbs_joypad_controller_write_register(`HWREG_GBS_CURRENT_SONG_NUMBER, 8'd0);

            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd0);

            gbs_joypad_controller_write_command(JOYPAD_COMMAND_NEXT_SONG);
            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd0);

            gbs_joypad_controller_write_command(JOYPAD_COMMAND_PREV_SONG);
            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd0);

            // 楽曲数2でテスト
            gbs_joypad_controller_reset();
            gbs_joypad_controller_write_register(`HWREG_GBS_NUMBER_OF_SONGS, 8'd2);
            gbs_joypad_controller_write_register(`HWREG_GBS_CURRENT_SONG_NUMBER, 8'd0);

            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd0);

            gbs_joypad_controller_write_command(JOYPAD_COMMAND_NEXT_SONG);
            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd1);

            gbs_joypad_controller_write_command(JOYPAD_COMMAND_NEXT_SONG);
            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd1);

            gbs_joypad_controller_write_command(JOYPAD_COMMAND_PREV_SONG);
            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd0);

            gbs_joypad_controller_write_command(JOYPAD_COMMAND_PREV_SONG);
            gbs_joypad_controller_read_register(`HWREG_GBS_CURRENT_SONG_NUMBER, r_reg);
            `EXPECT_EQ(r_reg, 8'd0);
        end
    endtask

    initial begin
        $dumpfile("build/test_gbs_joypad_controller.vcd");
        $dumpvars(0, test_gbs_joypad_controller);

        clk = 0;

        gbs_joypad_controller_change_song();

        $finish;
    end

endmodule
