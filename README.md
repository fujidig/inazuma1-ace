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
