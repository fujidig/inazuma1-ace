#!/bin/bash
set -e
arm-none-eabi-as -mcpu=arm946e-s -o main.o main.s
arm-none-eabi-objcopy -O binary -j .text.main main.o main.bin

ruby modify-savedata.rb
ruby repair_saveram_crc.rb inazuma1.SaveRAM
