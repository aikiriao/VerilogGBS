module envelope_generator #(
    parameter CLOCK_HZ = 1048576 // クロック動作周波数
)(
    input wire i_clk, // クロック
    input wire i_rst_n, // 非同期リセット
    input wire i_we, // パラメータ書き込み
    input wire [3:0] i_initial_volume, // 初期ボリューム
    input wire i_volume_delta_direction, // ボリューム更新方向（0: -1、1: 1）
    input wire [2:0] i_volume_sweep_pace, // ボリューム更新スピード
    input wire i_trigger, // トリガー信号
    output reg [3:0] o_volume // ボリューム
);

    localparam APU_ENVELOPE_SWEEP_HZ = 64; // エンベロープジェネレータの更新頻度
    localparam CLK_UPDATE_COUNT_PERIOD = CLOCK_HZ / APU_ENVELOPE_SWEEP_HZ; // クロックの更新周期

    reg volume_delta_direction; // ボリューム更新方向
    reg [4:0] initial_volume; // ボリューム初期値
    reg [2:0] volume_sweep_pace; // ボリューム更新スピード（0は即時設定）
    reg [15:0] clk_count; // クロックカウント
    reg [2:0] timer_count; // タイマーカウント

    // 内部レジスタ更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            initial_volume <= 0;
            volume_delta_direction <= 0;
            volume_sweep_pace <= 0;
        end else if (i_we) begin
            initial_volume <= i_initial_volume;
            volume_delta_direction <= i_volume_delta_direction;
            volume_sweep_pace <= i_volume_sweep_pace;
        end
    end

    // トリガー・ボリューム更新
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n) begin
            o_volume <= 0;
            clk_count <= 1;
            timer_count <= 1;
        end else if (i_trigger) begin
            // トリガー
            o_volume <= initial_volume;
            clk_count <= 1;
            timer_count <= 1;
        end else if (volume_sweep_pace != 0) begin
            // カウントアップ
            if (clk_count >= CLK_UPDATE_COUNT_PERIOD) begin
                if (timer_count >= volume_sweep_pace) begin
                    // ボリューム更新
                    if ((o_volume == 0) & !volume_delta_direction) begin
                        o_volume <= 0;
                    end else if ((o_volume == 4'hF) & volume_delta_direction) begin
                        o_volume <= 4'hF;
                    end else begin
                        o_volume <= volume_delta_direction ? (o_volume + 1) : (o_volume - 1);
                    end
                    timer_count <= 1;
                end else begin
                    timer_count <= timer_count + 1;
                end
                clk_count <= 1;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

endmodule
