`include "test.vh"
`timescale 1ns/1ns

module test_noise_generator;
    parameter STEP = 10;

    reg clk;
    reg rst_n;
    reg we_length_timer;
    reg we_volume_envelope;
    reg we_freqency_randomness;
    reg we_control;

    reg [5:0] initial_timer;
    reg [3:0] initial_volume;
    reg volume_delta_dir;
    reg [2:0] volume_sweep_pace;
    reg [3:0] clock_shift;
    reg lfsr_mode;
    reg [2:0] clock_divider;
    reg length_timer_enable;
    reg trigger;

    wire [3:0] signal;

    noise_generator #(
        .CLOCK_HZ(2097152)
    ) ng (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_we_length_timer(we_length_timer),
        .i_initial_timer(initial_timer),
        .i_we_volume_envelope(we_volume_envelope),
        .i_initial_volume(initial_volume),
        .i_volume_delta_dir(volume_delta_dir),
        .i_volume_sweep_pace(volume_sweep_pace),
        .i_we_frequency_randomness(we_frequency_randomness),
        .i_clock_shift(clock_shift),
        .i_lfsr_mode(lfsr_mode),
        .i_clock_divider(clock_divider),
        .i_we_control(we_control),
        .i_length_timer_enable(length_timer_enable),
        .i_trigger(trigger),
        .o_signal(signal)
    );

    always #(STEP/2) begin
        clk <= ~clk;
    end

    initial begin
        $dumpfile("build/test_noise_generator.vcd");
        $dumpvars(0, test_noise_generator);

        clk <= 0;

        $finish;
    end
endmodule
