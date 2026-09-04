# inazuma1-ace

DSの某サッカーゲームのセーブデータを編集し、任意コードを実行します。

## 必要なもの

- arm-none-eabi-as
- arm-none-eabi-objcopy
- Ruby 4.0

## 使い方

1. もととなるセーブデータ inazuma1.base.SaveRAM をトップディレクトリに置く。
2. ./compile.sh を実行
3. inazuma1.SaveRAM ができる

## 注意

arm7exe.bin, arm9exe.binを別の内容に変更すれば別のプログラムも実行できますが、現状、エントリーポイントやARM9, ARM7それぞれの長さなどは.sファイル内で決めうちしています。
