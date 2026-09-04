savedata = File.binread("inazuma1.base.SaveRAM")
data = "
    58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58 58
    59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59 59
    59 59 59 59
".scan(/[0-9A-Fa-f]{2}/).map{|x| x.to_i(16).chr }.join

BASE_ADDR = 0x0228ec8c


bin = File.binread("main.bin")

data += [BASE_ADDR + 3 * 0x20 + 32 + 36 + 4].pack("V")
data += bin
savedata[0x4d48 + 3 * 0x20, data.length] = data
arm9 = File.binread("arm9exe.bin")
savedata[0x40 + 1 * 0x5540 + 0x80, arm9.length] = arm9
arm7 = File.binread("arm7exe.bin")
savedata[0x40 + 1 * 0x5540 + 0x80 + arm9.length, arm7.length] = arm7
File.binwrite "inazuma1.SaveRAM", savedata

#File.binwrite "tmp.bin", data
#system "arm-none-eabi-objdump", "-b", "binary", "-m", "arm", "--adjust-vma=#{BASE_ADDR + 3 * 0x20}", "-D", "tmp.bin", {1 => "tmp.txt"}
