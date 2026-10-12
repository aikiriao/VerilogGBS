"""
RAMイメージ(.hex)を作成
"""
import argparse
import sys

RAM_SIZE = 0x8000

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output_file", type=str, help="specify output hex file")

    args = parser.parse_args()

    with open(args.output_file, 'w', encoding='UTF-8') as fout:
        fout.write(f'// GBS RAM Image\n')
    
        # RAMイメージ書き出し
        i = 0;
        while i < RAM_SIZE:
            for j in range(32):
                if i + j < RAM_SIZE:
                    fout.write(f'{00} ')
            fout.write(f'\n')
            i += 32

