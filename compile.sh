#!/bin/bash
set -e
arm-none-eabi-as -mcpu=arm946e-s -o nds_red_stop.o nds_red_stop.s
arm-none-eabi-objcopy -O binary -j .text.nds_red_stop nds_red_stop.o nds_red_stop.bin

ruby modify-savedata.rb
ruby repair_saveram_crc.rb inazuma1.SaveRAM
