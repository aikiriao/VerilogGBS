module apu #(
    parameter CLOCK_HZ = 2097152, // クロック動作周波数
    parameter SIGNAL_BIT_WIDTH = 16 // 信号のビット深度
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we_register, // レジスタ書き込みイネーブル
    input wire i_re_register, // レジスタ読み込みイネーブル
    input wire [15:0] i_address, // アドレス
    input wire [7:0] i_w_data, // 書き込みデータ
    output wire [7:0] o_r_data, // 読み込みデータ
    output wire signed [SIGNAL_BIT_WIDTH - 1:0] o_l_signal, // 左チャンネル信号
    output wire signed [SIGNAL_BIT_WIDTH - 1:0] o_r_signal // 右チャンネル信号
);

    // レジスタアドレス定義
    `include "sm83_register_address.vh"

    // 各レジスタの書き込み信号
    wire nr10_write = i_we_register & (i_address == HWREG_NR10_CHANNEL1_SWEEP);
    wire nr11_write = i_we_register & (i_address == HWREG_NR11_CHANNEL1_LENGTH_TIMER_DURY_CYCLE);
    wire nr12_write = i_we_register & (i_address == HWREG_NR12_CHANNEL1_VOLUME_ENVELOPE);
    wire nr13_write = i_we_register & (i_address == HWREG_NR13_CHANNEL1_PERIOD_LOW);
    wire nr14_write = i_we_register & (i_address == HWREG_NR14_CHANNEL1_PERIOD_HIGH_CONTROL);
    wire nr21_write = i_we_register & (i_address == HWREG_NR21_CHANNEL2_LENGTH_TIMER_DURY_CYCLE);
    wire nr22_write = i_we_register & (i_address == HWREG_NR22_CHANNEL1_VOLUME_ENVELOPE);
    wire nr23_write = i_we_register & (i_address == HWREG_NR23_CHANNEL1_PERIOD_LOW);
    wire nr24_write = i_we_register & (i_address == HWREG_NR24_CHANNEL1_PERIOD_HIGH_CONTROL);
    wire nr30_write = i_we_register & (i_address == HWREG_NR30_CHANNEL3_DAC_ENABLE);
    wire nr31_write = i_we_register & (i_address == HWREG_NR31_CHANNEL3_LENGTH_TIMER);
    wire nr32_write = i_we_register & (i_address == HWREG_NR32_CHANNEL3_OUTPUT_LEVEL);
    wire nr33_write = i_we_register & (i_address == HWREG_NR33_CHANNEL3_PERIOD_HIGH_CONTROL);
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
    reg [3:0] ch_signal[0:3];

    // APUレジスタ
    reg [7:0] nr10_ch1_sweep;
    reg [7:0] nr11_ch1_timer_duty_datio;
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
        .i_period_sweep_pace(8'h0),
        .i_period_sweep_direction(8'h0),
        .i_period_sweep_step(8'h0),
        .i_we_length_timer_duty_ratio(nr22_write),
        .i_duty_ratio(i_w_data[7:6]),
        .i_initial_timer(i_w_data[5:0]),
        .i_we_volume_envelope(nr23_write),
        .i_initial_volume(i_w_data[7:4]),
        .i_volume_delta_direction(i_w_data[3]),
        .i_volume_sweep_pace(i_w_data[2:0]),
        .i_we_period_low(nr24_write),
        .i_period_low(i_w_data),
        .i_we_period_high_control(nr25_write),
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
        .i_initial_timer(i_w_data),
        .i_we_output_level(nr32_write),
        .i_output_level(i_w_data[6:5]),
        .i_we_period_low(nr33_write),
        .i_period_low(i_w_data),
        .i_we_wave_ram(waveram_write),
        .i_wave_even_index((i_address - HWREG_CHANNEL3_WAVE_PATTERN_RAM_START) << 1),
        .i_wave_2pcm(i_w_data),
        .i_we_period_high_control(nr34_write),
        .i_period_high(i_w_data[2:0]),
        .i_length_timer_enable(i_w_data[6]),
        .i_trigger(i_w_data[7]),
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
            nr11_ch1_timer_duty_datio <= 0;
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

endmodule
