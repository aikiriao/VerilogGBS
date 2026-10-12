"""
GBSファイル(.gbs)からROMイメージ(.hex)を作成
"""
import argparse
import sys

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input_file", type=str, help="specify input gbs file")
    parser.add_argument("output_file", type=str, help="specify output hex file")

    args = parser.parse_args()

    with open(args.input_file, 'rb') as fin:
        data = fin.read()
        version = data[0x3]
        num_songs = data[0x4]
        first_song = data[0x5]
        load_address = data[0x6] | (data[0x7] << 8)
        init_address = data[0x8] | (data[0x9] << 8)
        play_address = data[0xA] | (data[0xB] << 8)
        stack_pointer = data[0xC] | (data[0xD] << 8)
        timer_modulo = data[0xE]
        timer_control = data[0xF]
        title = data[0x10:(0x10 + 32)].rstrip(b'\x00').decode('ascii')
        author = data[0x30:(0x30 + 32)].rstrip(b'\x00').decode('ascii')
        copyright = data[0x50:(0x50 + 32)].rstrip(b'\x00').decode('ascii')
        
        print(f'GBS File Version: {version}')
        print(f'Title: {title}')
        print(f'Author: {author}')
        print(f'Copyright: {copyright}')
        print(f'Number of Songs: {num_songs}')
        print(f'First Song: {first_song}')
        print(f'Load Address: {load_address:4X}')
        print(f'Init Address: {init_address:4X}')
        print(f'Play Address: {play_address:4X}')
        print(f'Stack Pointer: {stack_pointer:4X}')
        print(f'Timer Modulo: {timer_modulo:2X}')
        print(f'Timer Control: {timer_control:2X}')

        # ロードアドレスがブートストラップコードに被る
        if (load_address < 0x50):
            print('Error: ROM image overlap to bootstrap code')
            sys.exit(1)

        with open(args.output_file, 'w', encoding='UTF-8') as fout:
            fout.write(f'// GBS File Version: {version}\n')
            fout.write(f'// Title: {title}\n')
            fout.write(f'// Author: {author}\n')
            fout.write(f'// Copyright: {copyright}\n')
            fout.write(f'// Number of Songs: {num_songs}\n')
            fout.write(f'// First Song: {first_song}\n')
            fout.write(f'// Load Address: {load_address:4X}\n')
            fout.write(f'// Init Address: {init_address:4X}\n')
            fout.write(f'// Play Address: {play_address:4X}\n')
            fout.write(f'// Stack Pointer: {stack_pointer:4X}\n')
            fout.write(f'// Timer Modulo: {timer_modulo:2X}\n')
            fout.write(f'// Timer Control: {timer_control:2X}\n')

            # EDAによっては@<address>形式のロードをサポートしていないので、先頭アドレスからのROMイメージを生成
            rom_size = len(data) - 0x70 + load_address
            rom = [0] * rom_size
            rom[load_address:] = data[0x70:]

            # ブートストラップコードの書き込み
            # スタックポインタの設定
            # LD SP, stack_pointer
            rom[0x00] = 0x31
            rom[0x01] = (stack_pointer >> 0) & 0xFF
            rom[0x02] = (stack_pointer >> 8) & 0xFF
            # TMAの設定
            # LD A, timer_modulo
            rom[0x03] = 0x3E
            rom[0x04] = timer_modulo
            # LDH [0x06], A
            rom[0x05] = 0xE0
            rom[0x06] = 0x06
            # TACの設定
            # LD A, timer_control
            rom[0x07] = 0x3E
            rom[0x08] = timer_control
            # LDH [0x07], A
            rom[0x09] = 0xE0
            rom[0x0A] = 0x07
            # 再生楽曲番号をAに設定
            # LD A, first_song
            rom[0x0B] = 0x3E
            rom[0x0C] = first_song
            # Initルーチン呼び出し
            # CALL init_address
            rom[0x0D] = 0xCD
            rom[0x0E] = (init_address >> 0) & 0xFF
            rom[0x0F] = (init_address >> 8) & 0xFF
            # 割り込み有効
            # LD A, 0x1F
            rom[0x10] = 0x3E
            rom[0x11] = 0x1F
            # LDH [0xFF], A
            rom[0x12] = 0xE0
            rom[0x13] = 0xFF
            # EI
            rom[0x14] = 0xFB
            # 無限ループ（割り込み待ち）
            # JR -2
            rom[0x15] = 0x18
            rom[0x16] = 0xFE

            # 0x40に割込みルーチンを仕込む
            # CALL play_address
            rom[0x40] = 0xCD
            rom[0x41] = (play_address >> 0) & 0xFF
            rom[0x42] = (play_address >> 8) & 0xFF
            # RETI
            rom[0x43] = 0xD9

            # 0x50に割り込みルーチンを仕込む
            # CALL play_address
            rom[0x50] = 0xCD
            rom[0x51] = (play_address >> 0) & 0xFF
            rom[0x52] = (play_address >> 8) & 0xFF
            # RETI
            rom[0x53] = 0xD9

            # ROMイメージ書き出し
            i = 0;
            while i < rom_size:
                for j in range(32):
                    if i + j < rom_size:
                        fout.write(f'{rom[i + j]:02X} ')
                fout.write(f'\n')
                i += 32

