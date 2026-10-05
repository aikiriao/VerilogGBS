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

            # ブートストラップコード
            fout.write(f'@0\n')
            fout.write(f'// SPの設定 \n')
            fout.write(f'31 {((stack_pointer >> 0) & 0xFF):02X} {((stack_pointer >> 8) & 0xFF):02X} // LD SP, {stack_pointer:04X} \n')
            fout.write(f'// TMA/TACの設定 \n')
            fout.write(f'3E {timer_modulo:02X} // LD A, {timer_modulo:02X} \n')
            fout.write(f'E0 06 // LDH [0x06], A \n')
            fout.write(f'3E {timer_control:02X} // LD A, {timer_control:02X} \n')
            fout.write(f'E0 07 // LDH [0x07], A \n')
            fout.write(f'// A（再生楽曲番号） ここを差し替えると楽曲を変えられる \n')
            fout.write(f'3E {first_song:02X} // LD A, {first_song:02X} \n')
            fout.write(f'// Initルーチン呼び出し \n')
            fout.write(f'CD {((init_address >> 0) & 0xFF):02X} {((init_address >> 8) & 0xFF):02X} // CALL {init_address:04X} \n')
            fout.write(f'// 割り込み有効 \n')
            fout.write(f'3E 1F // LD A, 1F \n')
            fout.write(f'E0 FF // LDH [0xFF], A \n')
            fout.write(f'FB // EI \n')
            fout.write(f'// 無限ループ（再生待機） \n')
            fout.write(f'18 FE // JR -2 \n')
            fout.write(f'// Playルーチンを割り込みに仕込む \n')
            fout.write(f'@40\n')
            fout.write(f'CD {((play_address >> 0) & 0xFF):02X} {((play_address >> 8) & 0xFF):02X} // CALL {play_address:04X} \n')
            fout.write(f'D9 // RETI \n')
            fout.write(f'@50\n')
            fout.write(f'CD {((play_address >> 0) & 0xFF):02X} {((play_address >> 8) & 0xFF):02X} // CALL {play_address:04X} \n')
            fout.write(f'D9 // RETI \n')

            # ROMイメージ
            fout.write(f'@{load_address:4X}\n')
            rom_size = len(data) - 0x70
            rom = data[0x70:]
            i = 0;
            while i < rom_size:
                for j in range(32):
                    if i + j < rom_size:
                        fout.write(f'{rom[i + j]:02X} ')
                fout.write(f'\n')
                i += 32

