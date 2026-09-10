`ifndef SM83_REGISTER_ADDRESS_VH
`define SM83_REGISTER_ADDRESS_VH

// アドレス定義

// Bank0 ROM開始アドレス
localparam [15:0] ROM_BANK0_START_ADDRESS = 16'h0000;
// Bank1 ROM開始アドレス
localparam [15:0] ROM_BANK1_START_ADDRESS = 16'h4000;
// VRAM開始アドレス
localparam [15:0] VRAM_START_ADDRESS = 16'h8000;
// 外部RAM開始アドレス
localparam [15:0] EXTERNAL_RAM_START_ADDRESS = 16'hA000;
// Work RAM
localparam [15:0] WRAM_BANK0_START_ADDRESS = 16'hC000;
// Work RAM Bank 1-7
localparam [15:0] WRAM_BANK1_START_ADDRESS = 16'hD000;
// Echo RAM
localparam [15:0] ECHO_RAM_START_ADDRESS = 16'hE000;
// Object Attribute Memory (OAM)
localparam [15:0] OAM_START_ADDRESS = 16'hFE00;
localparam [15:0] NOT_USABLE_START_ADDRESS = 16'hFEA0;
// ハードウェアレジスタの開始アドレス
localparam [15:0] HWREG_START_ADDRESS = 16'hFF00;
// High RAM (HRAM)
localparam [15:0] HRAM_START_ADDRESS = 16'hFF80;

// ハードウェアレジスタアドレス
// ジョイパッド
localparam [15:0] HWREG_P1_JOYPAD = 16'hFF00;
// シリアル通信データ
localparam [15:0] HWREG_SB_SERIAL_TRANSFER_DATA = 16'hFF01;
// シリアル通信制御
localparam [15:0] HWREG_SC_SERIAL_TRANSFER_CONTROL = 16'hFF02;
// 単調増加タイマー
localparam [15:0] HWREG_DIV_REGISTER = 16'hFF04;
// タイマーカウンタ
localparam [15:0] HWREG_TIMA_TIMER_COUNTER = 16'hFF05;
// タイマー剰余
localparam [15:0] HWREG_TMA_TIMER_MODULO = 16'hFF06;
// タイマー制御
localparam [15:0] HWREG_TAC_TIMER_CONTROL = 16'hFF07;
// 割り込みフラグ
localparam [15:0] HWREG_IF_INTERRUPT_FLAG = 16'hFF0F;
// チャンネル1スイープ
localparam [15:0] HWREG_NR10_CHANNEL1_SWEEP = 16'hFF10;
// チャンネル1長さタイマー・デューティ比
localparam [15:0] HWREG_NR11_CHANNEL1_LENGTH_TIMER_DURY_CYCLE = 16'hFF11;
// チャンネル1ボリューム・エンベロープ
localparam [15:0] HWREG_NR12_CHANNEL1_VOLUME_ENVELOPE = 16'hFF12;
// チャンネル1周期下位ビット
localparam [15:0] HWREG_NR13_CHANNEL1_PERIOD_LOW = 16'hFF13;
// チャンネル1周期上位ビット・制御ビット
localparam [15:0] HWREG_NR14_CHANNEL1_PERIOD_HIGH_CONTROL = 16'hFF14;
// チャンネル2長さタイマー・デューティ比
localparam [15:0] HWREG_NR21_CHANNEL2_LENGTH_TIMER_DURY_CYCLE = 16'hFF16;
// チャンネル2ボリューム・エンベロープ
localparam [15:0] HWREG_NR22_CHANNEL2_VOLUME_ENVELOPE = 16'hFF17;
// チャンネル2周期下位ビット
localparam [15:0] HWREG_NR23_CHANNEL2_PERIOD_LOW = 16'hFF18;
// チャンネル2周期上位ビット・制御ビット
localparam [15:0] HWREG_NR24_CHANNEL2_PERIOD_HIGH_CONTROL = 16'hFF19;
// チャンネル3DAC有効フラグ
localparam [15:0] HWREG_NR30_CHANNEL3_DAC_ENABLE = 16'hFF1A;
// チャンネル3長さタイマー
localparam [15:0] HWREG_NR31_CHANNEL3_LENGTH_TIMER = 16'hFF1B;
// チャンネル3出力レベル
localparam [15:0] HWREG_NR32_CHANNEL3_OUTPUT_LEVEL = 16'hFF1C;
// チャンネル3周期下位ビット
localparam [15:0] HWREG_NR33_CHANNEL3_PERIOD_LOW = 16'hFF1D;
// チャンネル3周期上位ビット・制御ビット
localparam [15:0] HWREG_NR34_CHANNEL3_PERIOD_HIGH_CONTROL = 16'hFF1E;
// チャンネル4長さタイマー
localparam [15:0] HWREG_NR41_CHANNEL4_LENGTH_TIMER = 16'hFF20;
// チャンネル4ボリューム・エンベロープ
localparam [15:0] HWREG_NR42_CHANNEL4_VOLUME_ENVELOPE = 16'hFF21;
// チャンネル4周波数・ランダム度
localparam [15:0] HWREG_NR43_CHANNEL4_FREQUENCY_RANDOMNESS = 16'hFF22;
// チャンネル4制御
localparam [15:0] HWREG_NR44_CHANNEL4_CONTROL = 16'hFF23;
// マスターボリューム・外部音声出力のパン
localparam [15:0] HWREG_NR50_MASTER_VOLUME_VIN_PANNING = 16'hFF24;
// 各チャンネルのパン
localparam [15:0] HWREG_NR51_SOUND_PANNING = 16'hFF25;
// 全体と各チャンネルのオーディオON/OFF
localparam [15:0] HWREG_NR52_AUDIO_MASTER_CONTROL = 16'hFF26;
// チャンネル3の波形RAM
localparam [15:0] HWREG_CHANNEL3_WAVE_PATTERN_RAM_START = 16'hFF30;
// チャンネル3の波形RAM領域終端アドレス
localparam [15:0] HWREG_CHANNEL3_WAVE_PATTERN_RAM_END = (HWREG_CHANNEL3_WAVE_PATTERN_RAM_START + 15);
// LCD制御
localparam [15:0] HWREG_LCDC_LCD_CONTROL = 16'hFF40;
// LCDステータス
localparam [15:0] HWREG_STAT_LCD_STATUS = 16'hFF41;
// ビューポートのY座標
localparam [15:0] HWREG_SCY_VIEWPORT_Y = 16'hFF42;
// ビューポートのX座標
localparam [15:0] HWREG_SCX_VIEWPORT_X = 16'hFF43;
// LCDのY座標
localparam [15:0] HWREG_LY_LCD_Y_COORDINATE = 16'hFF44;
// LYとの比較
localparam [15:0] HWREG_LYC_LY_COMPARE = 16'hFF45;
// ROM/RAMからOAM(Object Attribute Memory)へのDMA転送アドレス
localparam [15:0] HWREG_DMA_SOURCE_ADDRESS_START = 16'hFF46;
// BGパレットデータ
localparam [15:0] HWREG_BGP_BG_PALETTE_DATA = 16'hFF47;
// パレット0のカラーインデックス
localparam [15:0] HWREG_OBP0_OBJ_PALETTE0 = 16'hFF48;
// パレット1のカラーインデックス
localparam [15:0] HWREG_OBP1_OBJ_PALETTE1 = 16'hFF49;
// ウィンドウのY座標
localparam [15:0] HWREG_WY_WINDOW_Y = 16'hFF4A;
// ウィンドウのX座標+7
localparam [15:0] HWREG_WX_WINDOW_X_PLUS_7 = 16'hFF4B;
// CPUモードセレクト
localparam [15:0] HWREG_KEY0_CPU_MODE_SELECT = 16'hFF4C;
// CGBの倍速モード/通常速モードに備える
localparam [15:0] HWREG_KEY1_PREPARE_SPEED_SWITCH = 16'hFF4D;
// VRAMバンク
localparam [15:0] HWREG_VBK_VRAM_BANK = 16'hFF4F;
// ブートROMのマッピング制御
localparam [15:0] HWREG_BANK_BOOTROM_MAPPING_CONTROL = 16'hFF50;
// VRAM DMAのソースアドレス上位
localparam [15:0] HWREG_HDMA1_VRAMDMA_SOURCE_HIGH = 16'hFF51;
// VRAM DMAのソースアドレス下位
localparam [15:0] HWREG_HDMA2_VRAMDMA_SOURCE_LOW = 16'hFF52;
// VRAM DMAのターゲットアドレス上位
localparam [15:0] HWREG_HDMA3_VRAMDMA_DESTINATION_HIGH = 16'hFF53;
// VRAM DMAのターゲットアドレス下位
localparam [15:0] HWREG_HDMA4_VRAMDMA_DESTINATION_LOW = 16'hFF54;
// VRAM DMAの長さ/モード/開始
localparam [15:0] HWREG_HDMA5_LENGTH_MODE_START = 16'hFF55;
// 赤外線通信ポート
localparam [15:0] HWREG_RP_INFRATED_COMMUNICATIONS_PORT = 16'hFF56;
// 背景カラーパレット仕様・インデックス
localparam [15:0] HWREG_BCPS_BACKGROUND_COLOR_PALETTE_SPECIFICATION = 16'hFF68;
// 背景カラーパレットデータ
localparam [15:0] HWREG_BCPS_BACKGROUND_COLOR_PALETTE_DATA = 16'hFF69;
// OBJカラーパレット仕様・インデックス
localparam [15:0] HWREG_OCPS_OBJ_COLOR_PALETTE_SPECIFICATION = 16'hFF6A;
// OBJカラーパレットデータ
localparam [15:0] HWREG_OCPS_OBJ_COLOR_PALETTE_DATA = 16'hFF6B;
// オブジェクト優先度
localparam [15:0] HWREG_OPRI_OBJECT_PRIOROTY_MODE = 16'hFF6C;
// WRAMバンク
localparam [15:0] HWREG_SVBK_WRAM_BANK = 16'hFF70;
// チャンネル1,2のオーディオデジタル出力
localparam [15:0] HWREG_PCM12_AUDIO_DIGITAL_OUTPUTS_12 = 16'hFF76;
// チャンネル3,4のオーディオデジタル出力
localparam [15:0] HWREG_PCM34_AUDIO_DIGITAL_OUTPUTS_34 = 16'hFF77;
// 割り込み有効フラグ
localparam [15:0] HWREG_IE_INTERRUPT_ENABLE = 16'hFFFF;

`endif //  SM83_REGISTER_ADDRESS_VH
