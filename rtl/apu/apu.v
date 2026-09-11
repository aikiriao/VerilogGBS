`timescale 1ns/1ns

module apu #(
    parameter CLOCK_HZ = 2097152, // クロック動作周波数
    parameter SIGNAL_BIT_WIDTH = 16 // 出力信号のビット深度
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_register, // レジスタ書き込みイネーブル
    input wire [15:0] i_address, // アドレス
    input wire [7:0] i_w_data, // 書き込みデータ
    output wire [7:0] o_r_data, // 読み込みデータ
    output reg signed [SIGNAL_BIT_WIDTH-1:0] o_l_signal, // 左チャンネル信号
    output reg signed [SIGNAL_BIT_WIDTH-1:0] o_r_signal // 右チャンネル信号
);

    // レジスタアドレス定義
    `include "sm83_register_address.vh"

    localparam HPF_COEFFIENT_FIXED = $rtoi(0.999958 * (1 << (SIGNAL_BIT_WIDTH - 1)));
    localparam [SIGNAL_BIT_WIDTH-1:0] HPF_COEFFIENT = HPF_COEFFIENT_FIXED[SIGNAL_BIT_WIDTH-1:0]; // HPF係数

    // 各レジスタの書き込み信号
    wire nr10_write = i_we_register & (i_address == HWREG_NR10_CHANNEL1_SWEEP);
    wire nr11_write = i_we_register & (i_address == HWREG_NR11_CHANNEL1_LENGTH_TIMER_DURY_CYCLE);
    wire nr12_write = i_we_register & (i_address == HWREG_NR12_CHANNEL1_VOLUME_ENVELOPE);
    wire nr13_write = i_we_register & (i_address == HWREG_NR13_CHANNEL1_PERIOD_LOW);
    wire nr14_write = i_we_register & (i_address == HWREG_NR14_CHANNEL1_PERIOD_HIGH_CONTROL);
    wire nr21_write = i_we_register & (i_address == HWREG_NR21_CHANNEL2_LENGTH_TIMER_DURY_CYCLE);
    wire nr22_write = i_we_register & (i_address == HWREG_NR22_CHANNEL2_VOLUME_ENVELOPE);
    wire nr23_write = i_we_register & (i_address == HWREG_NR23_CHANNEL2_PERIOD_LOW);
    wire nr24_write = i_we_register & (i_address == HWREG_NR24_CHANNEL2_PERIOD_HIGH_CONTROL);
    wire nr30_write = i_we_register & (i_address == HWREG_NR30_CHANNEL3_DAC_ENABLE);
    wire nr31_write = i_we_register & (i_address == HWREG_NR31_CHANNEL3_LENGTH_TIMER);
    wire nr32_write = i_we_register & (i_address == HWREG_NR32_CHANNEL3_OUTPUT_LEVEL);
    wire nr33_write = i_we_register & (i_address == HWREG_NR33_CHANNEL3_PERIOD_LOW);
    wire nr34_write = i_we_register & (i_address == HWREG_NR34_CHANNEL3_PERIOD_HIGH_CONTROL);
    wire nr41_write = i_we_register & (i_address == HWREG_NR41_CHANNEL4_LENGTH_TIMER);
    wire nr42_write = i_we_register & (i_address == HWREG_NR42_CHANNEL4_VOLUME_ENVELOPE);
    wire nr43_write = i_we_register & (i_address == HWREG_NR43_CHANNEL4_FREQUENCY_RANDOMNESS);
    wire nr44_write = i_we_register & (i_address == HWREG_NR44_CHANNEL4_CONTROL);
    wire nr50_write = i_we_register & (i_address == HWREG_NR50_MASTER_VOLUME_VIN_PANNING);
    wire nr51_write = i_we_register & (i_address == HWREG_NR51_SOUND_PANNING);
    wire nr52_write = i_we_register & (i_address == HWREG_NR52_AUDIO_MASTER_CONTROL);
    wire waveram_write = i_we_register & (i_address >= HWREG_CHANNEL3_WAVE_PATTERN_RAM_START) & (i_address <= HWREG_CHANNEL3_WAVE_PATTERN_RAM_END);

    // 各チャンネルの出力フラグと出力信号
    wire [3:0] ch_enable;
    wire [3:0] ch_dac_enable;
    wire [3:0] ch_signal[0:3];
    wire [7:0] r_sg_wave_pcm;
    wire signed [7:0] dac_signal[0:3];
    wire signed [7:0] mixed_l_signal;
    wire signed [7:0] mixed_r_signal;
    wire signed [7:0] l_signal;
    wire signed [7:0] r_signal;
    wire signed [SIGNAL_BIT_WIDTH-1:0] ex_l_signal;
    wire signed [SIGNAL_BIT_WIDTH-1:0] ex_r_signal;
    wire signed [SIGNAL_BIT_WIDTH-1:0] out_l;
    wire signed [SIGNAL_BIT_WIDTH-1:0] out_r;

    reg [SIGNAL_BIT_WIDTH-1:0] hpf_buffer_l;
    reg [SIGNAL_BIT_WIDTH-1:0] hpf_buffer_r;

    // APUレジスタ
    reg [7:0] nr10_ch1_sweep;
    reg [7:0] nr11_ch1_timer_duty_ratio;
    reg [7:0] nr12_ch1_volume_envelope;
    reg [7:0] nr13_ch1_period_low;
    reg [7:0] nr14_ch1_period_high_control;
    reg [7:0] nr21_ch2_timer_duty_ratio;
    reg [7:0] nr22_ch2_volume_envelope;
    reg [7:0] nr23_ch2_period_low;
    reg [7:0] nr24_ch2_period_high_control;
    reg [7:0] nr30_ch3_dac_enable;
    reg [7:0] nr31_ch3_length_timer;
    reg [7:0] nr32_ch3_output_level;
    reg [7:0] nr33_ch3_period_low;
    reg [7:0] nr34_ch3_period_high_control;
    reg [7:0] nr41_ch4_length_timer;
    reg [7:0] nr42_ch4_volume_envelope;
    reg [7:0] nr43_ch4_frequency_randomness;
    reg [7:0] nr44_ch4_control;
    reg [7:0] nr50_master_volume_vin_panning;
    reg [7:0] nr51_sound_panning;
    reg [7:0] nr52_audio_master_control;

    pulse_generator #(
        .CLOCK_HZ(CLOCK_HZ)
    ) pg1 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_period_sweep(nr10_write),
        .i_period_sweep_pace(i_w_data[6:4]),
        .i_period_sweep_direction(i_w_data[3]),
        .i_period_sweep_step(i_w_data[2:0]),
        .i_we_length_timer_duty_ratio(nr11_write),
        .i_duty_ratio(i_w_data[7:6]),
        .i_initial_timer(i_w_data[5:0]),
        .i_we_volume_envelope(nr12_write),
        .i_initial_volume(i_w_data[7:4]),
        .i_volume_delta_direction(i_w_data[3]),
        .i_volume_sweep_pace(i_w_data[2:0]),
        .i_we_period_low(nr13_write),
        .i_period_low(i_w_data),
        .i_we_period_high_control(nr14_write),
        .i_period_high(i_w_data[2:0]),
        .i_length_timer_enable(i_w_data[6]),
        .i_trigger(i_w_data[7]),
        .o_enable(ch_enable[0]),
        .o_dac_enable(ch_dac_enable[0]),
        .o_signal(ch_signal[0])
    );

    pulse_generator #(
        .CLOCK_HZ(CLOCK_HZ)
    ) pg2 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        // スイープに関するポートは0にして無効化
        .i_we_period_sweep(0),
        .i_period_sweep_pace(3'h0),
        .i_period_sweep_direction(1'h0),
        .i_period_sweep_step(3'h0),
        .i_we_length_timer_duty_ratio(nr21_write),
        .i_duty_ratio(i_w_data[7:6]),
        .i_initial_timer(i_w_data[5:0]),
        .i_we_volume_envelope(nr22_write),
        .i_initial_volume(i_w_data[7:4]),
        .i_volume_delta_direction(i_w_data[3]),
        .i_volume_sweep_pace(i_w_data[2:0]),
        .i_we_period_low(nr23_write),
        .i_period_low(i_w_data),
        .i_we_period_high_control(nr24_write),
        .i_period_high(i_w_data[2:0]),
        .i_length_timer_enable(i_w_data[6]),
        .i_trigger(i_w_data[7]),
        .o_enable(ch_enable[1]),
        .o_dac_enable(ch_dac_enable[1]),
        .o_signal(ch_signal[1])
    );

    sample_generator #(
        .CLOCK_HZ(CLOCK_HZ)
    ) sg (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_dac_enable(nr30_write),
        .i_dac_enable(i_w_data[7]),
        .i_we_length_timer(nr31_write),
        .i_initial_timer(i_w_data[5:0]),
        .i_we_output_level(nr32_write),
        .i_output_level(i_w_data[6:5]),
        .i_we_period_low(nr33_write),
        .i_period_low(i_w_data),
        .i_we_wave_ram(waveram_write),
        .i_wave_even_index({i_address[3:0], 1'd0}),
        .i_wave_2pcm(i_w_data),
        .i_we_period_high_control(nr34_write),
        .i_period_high(i_w_data[2:0]),
        .i_length_timer_enable(i_w_data[6]),
        .i_trigger(i_w_data[7]),
        .o_wave_2pcm(r_sg_wave_pcm),
        .o_enable(ch_enable[2]),
        .o_dac_enable(ch_dac_enable[2]),
        .o_signal(ch_signal[2])
    );

    noise_generator #(
        .CLOCK_HZ(CLOCK_HZ)
    ) ng (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_we_length_timer(nr41_write),
        .i_initial_timer(i_w_data[5:0]),
        .i_we_volume_envelope(nr42_write),
        .i_initial_volume(i_w_data[7:4]),
        .i_volume_delta_direction(i_w_data[3]),
        .i_volume_sweep_pace(i_w_data[2:0]),
        .i_we_frequency_randomness(nr43_write),
        .i_clock_shift(i_w_data[7:4]),
        .i_lfsr_mode(i_w_data[3]),
        .i_clock_divider(i_w_data[2:0]),
        .i_we_control(nr44_write),
        .i_length_timer_enable(i_w_data[6]),
        .i_trigger(i_w_data[7]),
        .o_enable(ch_enable[3]),
        .o_dac_enable(ch_dac_enable[3]),
        .o_signal(ch_signal[3])
    );
    
    // レジスタ更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            nr10_ch1_sweep <= 0;
            nr11_ch1_timer_duty_ratio <= 0;
            nr12_ch1_volume_envelope <= 0;
            nr13_ch1_period_low <= 0;
            nr14_ch1_period_high_control <= 0;
            nr21_ch2_timer_duty_ratio <= 0;
            nr22_ch2_volume_envelope <= 0;
            nr23_ch2_period_low <= 0;
            nr24_ch2_period_high_control <= 0;
            nr30_ch3_dac_enable <= 0;
            nr31_ch3_length_timer <= 0;
            nr32_ch3_output_level <= 0;
            nr33_ch3_period_low <= 0;
            nr34_ch3_period_high_control <= 0;
            nr41_ch4_length_timer <= 0;
            nr42_ch4_volume_envelope <= 0;
            nr43_ch4_frequency_randomness <= 0;
            nr44_ch4_control <= 0;
            nr50_master_volume_vin_panning <= 0;
            nr51_sound_panning <= 0;
            nr52_audio_master_control <= 0;
        end else begin
            if (nr10_write) nr10_ch1_sweep <= i_w_data;
            if (nr11_write) nr11_ch1_timer_duty_ratio <= i_w_data;
            if (nr12_write) nr12_ch1_volume_envelope <= i_w_data;
            if (nr13_write) nr13_ch1_period_low <= i_w_data;
            if (nr14_write) nr14_ch1_period_high_control <= i_w_data;
            if (nr21_write) nr21_ch2_timer_duty_ratio <= i_w_data;
            if (nr22_write) nr22_ch2_volume_envelope <= i_w_data;
            if (nr23_write) nr23_ch2_period_low <= i_w_data;
            if (nr24_write) nr24_ch2_period_high_control <= i_w_data;
            if (nr30_write) nr30_ch3_dac_enable <= i_w_data;
            if (nr31_write) nr31_ch3_length_timer <= i_w_data;
            if (nr32_write) nr32_ch3_output_level <= i_w_data;
            if (nr33_write) nr33_ch3_period_low <= i_w_data;
            if (nr34_write) nr34_ch3_period_high_control <= i_w_data;
            if (nr41_write) nr41_ch4_length_timer <= i_w_data;
            if (nr42_write) nr42_ch4_volume_envelope <= i_w_data;
            if (nr43_write) nr43_ch4_frequency_randomness <= i_w_data;
            if (nr44_write) nr44_ch4_control <= i_w_data;
            if (nr50_write) nr50_master_volume_vin_panning <= i_w_data;
            if (nr51_write) nr51_sound_panning <= i_w_data;
            if (nr52_write) nr52_audio_master_control <= i_w_data;
        end
    end

    // レジスタ読み取り
    function [7:0] read_register;
        input [15:0] address;

        if ((address >= HWREG_CHANNEL3_WAVE_PATTERN_RAM_START) 
                & (address <= HWREG_CHANNEL3_WAVE_PATTERN_RAM_END)) begin
            read_register = r_sg_wave_pcm;
        end else begin
            // TODO: 一部のレジスタは部分的に読み出せる
            case (address)
                HWREG_NR10_CHANNEL1_SWEEP:
                    read_register = nr10_ch1_sweep;
                HWREG_NR11_CHANNEL1_LENGTH_TIMER_DURY_CYCLE:
                    read_register = nr11_ch1_timer_duty_ratio;
                HWREG_NR12_CHANNEL1_VOLUME_ENVELOPE:
                    read_register = nr12_ch1_volume_envelope;
                HWREG_NR13_CHANNEL1_PERIOD_LOW:
                    read_register = nr13_ch1_period_low;
                HWREG_NR14_CHANNEL1_PERIOD_HIGH_CONTROL:
                    read_register = nr14_ch1_period_high_control;
                HWREG_NR21_CHANNEL2_LENGTH_TIMER_DURY_CYCLE:
                    read_register = nr21_ch2_timer_duty_ratio;
                HWREG_NR22_CHANNEL2_VOLUME_ENVELOPE:
                    read_register = nr22_ch2_volume_envelope;
                HWREG_NR23_CHANNEL2_PERIOD_LOW:
                    read_register = nr23_ch2_period_low;
                HWREG_NR24_CHANNEL2_PERIOD_HIGH_CONTROL:
                    read_register = nr24_ch2_period_high_control;
                HWREG_NR30_CHANNEL3_DAC_ENABLE:
                    read_register = nr30_ch3_dac_enable;
                HWREG_NR31_CHANNEL3_LENGTH_TIMER:
                    read_register = nr31_ch3_length_timer;
                HWREG_NR32_CHANNEL3_OUTPUT_LEVEL:
                    read_register = nr32_ch3_output_level;
                HWREG_NR33_CHANNEL3_PERIOD_LOW:
                    read_register = nr33_ch3_period_low;
                HWREG_NR34_CHANNEL3_PERIOD_HIGH_CONTROL:
                    read_register = nr34_ch3_period_high_control;
                HWREG_NR41_CHANNEL4_LENGTH_TIMER:
                    read_register = nr41_ch4_length_timer;
                HWREG_NR42_CHANNEL4_VOLUME_ENVELOPE:
                    read_register = nr42_ch4_volume_envelope;
                HWREG_NR43_CHANNEL4_FREQUENCY_RANDOMNESS:
                    read_register = nr43_ch4_frequency_randomness;
                HWREG_NR44_CHANNEL4_CONTROL:
                    read_register = nr44_ch4_control;
                HWREG_NR50_MASTER_VOLUME_VIN_PANNING:
                    read_register = nr50_master_volume_vin_panning;
                HWREG_NR51_SOUND_PANNING:
                    read_register = nr51_sound_panning;
                HWREG_NR52_AUDIO_MASTER_CONTROL:
                    read_register = nr52_audio_master_control;
                default:
                    read_register = 8'h00;
            endcase
        end
    endfunction

    // レジスタ読み取り
    assign o_r_data = read_register(i_address);

    // DAC（4bit符号なし -> 符号反転した8bit符号付き -15, ..., -1, 0, 1, ..., 15 にマップされる）
    function automatic signed [7:0] dac;
        input dac_enable;
        input [3:0] in;

        dac = dac_enable ? (8'd15 - $signed({4'b0000, in}) <<< 1) : 0;
    endfunction

    // DACに通す
    assign dac_signal[0] = dac(ch_dac_enable[0], ch_enable[0] ? ch_signal[0] : 4'd0);
    assign dac_signal[1] = dac(ch_dac_enable[1], ch_enable[1] ? ch_signal[1] : 4'd0);
    assign dac_signal[2] = dac(ch_dac_enable[2], ch_enable[2] ? ch_signal[2] : 4'd0);
    assign dac_signal[3] = dac(ch_dac_enable[3], ch_enable[3] ? ch_signal[3] : 4'd0);

    // ミックス・パンニング
    assign mixed_l_signal =
        (nr51_sound_panning[0] ? dac_signal[0] : 8'd0)
        + (nr51_sound_panning[1] ? dac_signal[1] : 8'd0)
        + (nr51_sound_panning[2] ? dac_signal[2] : 8'd0)
        + (nr51_sound_panning[3] ? dac_signal[3] : 8'd0);
    assign mixed_r_signal =
        (nr51_sound_panning[4] ? dac_signal[0] : 8'd0)
        + (nr51_sound_panning[5] ? dac_signal[1] : 8'd0)
        + (nr51_sound_panning[6] ? dac_signal[2] : 8'd0)
        + (nr51_sound_panning[7] ? dac_signal[3] : 8'd0);

    // マスターボリューム
    function automatic signed [7:0] apply_master_volume;
        input [2:0] volume;
        input [7:0] in;

        case (volume)
            3'd0: apply_master_volume = in >>> 3;
            3'd1: apply_master_volume = (2 * in) >>> 3;
            3'd2: apply_master_volume = (3 * in) >>> 3;
            3'd3: apply_master_volume = (4 * in) >>> 3;
            3'd4: apply_master_volume = (5 * in) >>> 3;
            3'd5: apply_master_volume = (6 * in) >>> 3;
            3'd6: apply_master_volume = (7 * in) >>> 3;
            3'd7: apply_master_volume = in;
            default: apply_master_volume = 0;
        endcase
    endfunction

    // マスターボリューム適用
    assign l_signal = apply_master_volume(nr52_audio_master_control[6:4], mixed_l_signal);
    assign r_signal = apply_master_volume(nr52_audio_master_control[2:0], mixed_r_signal);

    // ビット幅拡張
    assign ex_l_signal = {{8{l_signal[7]}}, l_signal} <<< (SIGNAL_BIT_WIDTH - 8);
    assign ex_r_signal = {{8{r_signal[7]}}, r_signal} <<< (SIGNAL_BIT_WIDTH - 8);

    // HPF適用
    assign out_l = ex_l_signal - hpf_buffer_l;
    assign out_r = ex_r_signal - hpf_buffer_r;
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_l_signal <= 0;
            o_r_signal <= 0;
            hpf_buffer_l <= 0;
            hpf_buffer_r <= 0;
        end else begin
            o_l_signal <= out_l;
            o_r_signal <= out_r;
            hpf_buffer_l <= ex_l_signal - ((out_l * HPF_COEFFIENT) >>> (SIGNAL_BIT_WIDTH - 1));
            hpf_buffer_r <= ex_r_signal - ((out_r * HPF_COEFFIENT) >>> (SIGNAL_BIT_WIDTH - 1));
        end
    end

endmodule
