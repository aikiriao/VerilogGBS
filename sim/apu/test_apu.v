`include "test.vh"
`include "sm83_register_address.vh"
`timescale 1ns/1ns

module test_apu;
    parameter STEP = 10;
    localparam SIGNAL_BIT_WIDTH = 16;

    reg clk;
    reg rst_n;
    reg we_register;
    reg tcycle_tick;
    reg [15:0] address;
    reg [7:0] w_data;
    wire [7:0] r_data;
    wire signed [SIGNAL_BIT_WIDTH-1:0] l_signal;
    wire signed [SIGNAL_BIT_WIDTH-1:0] r_signal;
    integer clk_count;

    apu #(
        .SIGNAL_BIT_WIDTH(SIGNAL_BIT_WIDTH)
    ) apu (
        .i_clk(clk),
        .i_tcycle_tick(tcycle_tick),
        .i_rst_n(rst_n),
        .i_we_register(we_register),
        .i_address(address),
        .i_w_data(w_data),
        .o_r_data(r_data),
        .o_l_signal(l_signal),
        .o_r_signal(r_signal)
    );

    always #(STEP/2) begin
        clk = ~clk;
    end

    always @(posedge clk) begin
        clk_count <= clk_count + 1;
    end

    // リセットタスク
    task automatic apu_reset;
        integer ch;

        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);
            rst_n = 1;

            `ASSERT_EQ(apu.ch_enable, 0);
            `ASSERT_EQ(apu.ch_dac_enable, 0);

            for (ch = 0; ch < 4; ch = ch + 1) begin
                `ASSERT_EQ(apu.ch_signal[ch], 0);
                `ASSERT_EQ(apu.dac_signal[ch], 0);
            end

            `ASSERT_EQ(apu.mixed_l_signal, 0);
            `ASSERT_EQ(apu.mixed_r_signal, 0);
            `ASSERT_EQ(apu.l_signal, 0);
            `ASSERT_EQ(apu.r_signal, 0);
            `ASSERT_EQ(apu.ex_l_signal, 0);
            `ASSERT_EQ(apu.out_l, 0);
            `ASSERT_EQ(apu.out_r, 0);
            `ASSERT_EQ(apu.ex_r_signal, 0);
            `ASSERT_EQ(apu.hpf_buffer_l, 0);
            `ASSERT_EQ(apu.hpf_buffer_r, 0);

            `ASSERT_EQ(apu.nr10_ch1_sweep, 0);
            `ASSERT_EQ(apu.nr11_ch1_timer_duty_ratio, 0);
            `ASSERT_EQ(apu.nr12_ch1_volume_envelope, 0);
            `ASSERT_EQ(apu.nr13_ch1_period_low, 0);
            `ASSERT_EQ(apu.nr14_ch1_period_high_control, 0);
            `ASSERT_EQ(apu.nr21_ch2_timer_duty_ratio, 0);
            `ASSERT_EQ(apu.nr22_ch2_volume_envelope, 0);
            `ASSERT_EQ(apu.nr23_ch2_period_low, 0);
            `ASSERT_EQ(apu.nr24_ch2_period_high_control, 0);
            `ASSERT_EQ(apu.nr30_ch3_dac_enable, 0);
            `ASSERT_EQ(apu.nr31_ch3_length_timer, 0);
            `ASSERT_EQ(apu.nr32_ch3_output_level, 0);
            `ASSERT_EQ(apu.nr33_ch3_period_low, 0);
            `ASSERT_EQ(apu.nr34_ch3_period_high_control, 0);
            `ASSERT_EQ(apu.nr41_ch4_length_timer, 0);
            `ASSERT_EQ(apu.nr42_ch4_volume_envelope, 0);
            `ASSERT_EQ(apu.nr43_ch4_frequency_randomness, 0);
            `ASSERT_EQ(apu.nr44_ch4_control, 0);
            `ASSERT_EQ(apu.nr50_master_volume_vin_panning, 0);
            `ASSERT_EQ(apu.nr51_sound_panning, 0);
            `ASSERT_EQ(apu.nr52_audio_master_control, 0);

            `ASSERT_EQ(l_signal, 0);
            `ASSERT_EQ(r_signal, 0);
            `ASSERT_EQ(r_data, 0);
        end
    endtask

    // レジスタ書き込み
    task automatic apu_write_register;
        input [15:0] in_address;
        input [7:0] in_w_data;

        begin
            address = in_address;
            w_data = in_w_data;

            we_register = 1;
            @(posedge clk);
            @(negedge clk);
            we_register = 0;
        end
    endtask

    task automatic apu_reference_test(
        input [8*128-1:0] input_file_path
    );
        integer fd;
        integer result;
        integer next_clock;
        reg [7:0] command;
        reg [15:0] write_address;
        reg [7:0] write_data;
        reg [3:0] ch_out[0:3];
        reg ch_enable[0:3];
        reg [15:0] lfsr;
        reg [2:0] pulse_table_index[0:1];
        reg [4:0] wave_ram_index;
        reg [8*256-1:0] line;

        begin
            fd = $fopen(input_file_path, "r");
            `ASSERT_NEQ(fd, 0);

            apu_reset();

            // ファイルの終端までループ
            clk_count = 0;
            while ($feof(fd) == 0) begin
                result = $fgets(line, fd);
                `ASSERT_TRUE(result > 0);
                result = $sscanf(line, "%d %s", next_clock, command);
                `ASSERT_TRUE(result > 0);

                // ソフトウェアのクロック-1まで進める
                // 理由：ソフトウェアの出力はクロック終了後の値だから
                `ASSERT_TRUE(next_clock >= clk_count);
                while (clk_count < (next_clock - 1)) begin
                    @(posedge clk);
                    @(negedge clk);
                end
                `ASSERT_EQ(next_clock - 1, clk_count);

                if (command == "W") begin
                    result = $sscanf(line, "%d %s %h %h", next_clock, command, write_address, write_data);
                    `ASSERT_EQ(result, 4);
                    $display("%d W %h %h", clk_count, write_address, write_data);
                    apu_write_register(write_address, write_data);
                end else if (command == "O") begin
                    result = $sscanf(line,
                        "%d %s %h %h %h %h %b %b %b %b %h %h %d %h",
                        next_clock, command,
                        ch_out[0], ch_out[1], ch_out[2], ch_out[3],
                        ch_enable[0], ch_enable[1], ch_enable[2], ch_enable[3],
                        pulse_table_index[0], pulse_table_index[1], wave_ram_index, lfsr
                    );
                    $display("%d %h %h %h %h %h %h %d %h",
                        next_clock, ch_out[0], ch_out[1], ch_out[2], ch_out[3],
                        apu.pg1.pulse_table_index, apu.pg2.pulse_table_index, apu.sg.wave_ram_index, apu.ng.lfsr);
                    `ASSERT_EQ(result, 14);
                    if ((ch_out[0] !== apu.ch_signal[0])
                        || (ch_out[1] !== apu.ch_signal[1])
                        || (ch_out[2] !== apu.ch_signal[2])
                        || (ch_out[3] !== apu.ch_signal[3])) begin
                        $display("Output Mismatch At %d clock", clk_count);
                        $display("Reference %h %h %h %h %h %h %d %h",
                            ch_out[0], ch_out[1], ch_out[2], ch_out[3],
                            pulse_table_index[0], pulse_table_index[1], wave_ram_index, lfsr);
                        $display("      RTL %h %h %h %h %h %h %d %h",
                            apu.ch_signal[0], apu.ch_signal[1], apu.ch_signal[2], apu.ch_signal[3],
                            apu.pg1.pulse_table_index, apu.pg2.pulse_table_index, apu.sg.wave_ram_index, apu.ng.lfsr);
                        $finish;
                    end
                    if ((ch_enable[0] !== apu.ch_enable[0])
                        || (ch_enable[1] !== apu.ch_enable[1])
                        || (ch_enable[2] !== apu.ch_enable[2])
                        || (ch_enable[3] !== apu.ch_enable[3])) begin
                        $display("Enable Flag Mismatch At %d clock", clk_count);
                        $display("Reference %b %b %b %b", ch_enable[0], ch_enable[1], ch_enable[2], ch_enable[3]);
                        $display("      RTL %b %b %b %b", apu.ch_enable[0], apu.ch_enable[1], apu.ch_enable[2], apu.ch_enable[3]);
                        $finish;
                    end
                end
            end

            // ファイルを閉じる
            $fclose(fd);
        end
    endtask

    initial begin
        $dumpfile("build/test_apu.vcd");
        $dumpvars(0, test_apu);

        tcycle_tick = 1;
        clk = 0;

        apu_reset();

        // CH1,2,3をトリガーしてみる
        // apu_write_register(`HWREG_NR12_CHANNEL1_VOLUME_ENVELOPE, 8'hF0);
        // apu_write_register(`HWREG_NR13_CHANNEL1_PERIOD_LOW, 8'hFF);
        // apu_write_register(`HWREG_NR14_CHANNEL1_PERIOD_HIGH_CONTROL, 8'h87);
        // apu_write_register(`HWREG_NR22_CHANNEL2_VOLUME_ENVELOPE, 8'hF0);
        // apu_write_register(`HWREG_NR23_CHANNEL2_PERIOD_LOW, 8'hFF);
        // apu_write_register(`HWREG_NR24_CHANNEL2_PERIOD_HIGH_CONTROL, 8'h87);
        // apu_write_register(`HWREG_NR42_CHANNEL4_VOLUME_ENVELOPE, 8'hF0);
        // apu_write_register(`HWREG_NR43_CHANNEL4_FREQUENCY_RANDOMNESS, 8'h08);
        // apu_write_register(`HWREG_NR44_CHANNEL4_CONTROL, 8'h80);
        // apu_write_register(`HWREG_NR51_SOUND_PANNING, 8'hFF);
        // apu_write_register(`HWREG_NR52_AUDIO_MASTER_CONTROL, 8'h77);
        // #(100000 * STEP)

        apu_reference_test("testdata/apu/pkred_op1.txt");

        $finish;
    end
endmodule
