`include "test.vh"
`timescale 1ns/1ns

module test_apu;
    parameter STEP = 10;
    localparam SIGNAL_BIT_WIDTH = 16;

    // レジスタアドレス定義
    `include "sm83_register_address.vh"

    reg clk;
    reg rst_n;
    reg we_register;
    reg [15:0] address;
    reg [7:0] w_data;
    wire [7:0] r_data;
    wire signed [SIGNAL_BIT_WIDTH-1:0] l_signal;
    wire signed [SIGNAL_BIT_WIDTH-1:0] r_signal;

    apu #(
        .CLOCK_HZ(2097152),
        .SIGNAL_BIT_WIDTH(SIGNAL_BIT_WIDTH)
    ) apu (
        .i_clk(clk),
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

    // リセットタスク
    task automatic apu_reset;
        integer ch;

        begin
            rst_n = 0;
            @(posedge clk);
            @(negedge clk);

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

    initial begin
        $dumpfile("build/test_apu.vcd");
        $dumpvars(0, test_apu);

        clk = 0;

        apu_reset();

        // CH1をトリガーしてみる
        apu_write_register(HWREG_NR13_CHANNEL1_PERIOD_LOW, 8'hFF);
        apu_write_register(HWREG_NR14_CHANNEL1_PERIOD_HIGH_CONTROL, 8'h87);

        #(100 * STEP)

        $finish;
    end
endmodule
