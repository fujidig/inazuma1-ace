#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

# Inazuma Eleven (YEEJ) SaveRAM layout
SAVE_SIZE           = 0x10000
MASTER_HEADER_SIZE  = 0x40
SLOT_COUNT          = 3
SLOT_SIZE           = 0x5540
SLOT_HEADER_SIZE    = 0x80
SLOT_PAYLOAD_SIZE   = 0x54c0
EXPECTED_MAGIC      = 0x19150a04
EXPECTED_DATA_SIZE  = 0x4dd8
CRC32_POLYNOMIAL    = 0x04c11db7
UINT32_MASK         = 0xffff_ffff

def reverse_bits(value, width)
  reversed = 0
  width.times do
    reversed = (reversed << 1) | (value & 1)
    value >>= 1
  end
  reversed
end

# This follows sub_02088cd4 in the game. It is equivalent to the usual
# CRC-32/ISO-HDLC (the CRC returned by Zlib.crc32), but is written this way to
# preserve the game's use of polynomial 0x04c11db7 and its bit reversals.
def game_crc32(bytes)
  crc = UINT32_MASK

  bytes.each_byte do |byte|
    crc ^= reverse_bits(byte, 8) << 24
    8.times do
      top_bit = crc & 0x8000_0000
      crc = (crc << 1) & UINT32_MASK
      crc ^= CRC32_POLYNOMIAL unless top_bit.zero?
    end
  end

  reverse_bits(crc, 32) ^ UINT32_MASK
end

def read_u32(data, offset)
  data.byteslice(offset, 4).unpack1("V")
end

def write_u32(data, offset, value)
  data[offset, 4] = [value].pack("V")
end

def parse_slots(value)
  slots = value.split(",").map do |part|
    Integer(part, 10)
  rescue ArgumentError
    raise OptionParser::InvalidArgument, "invalid slot: #{part.inspect}"
  end

  invalid = slots.reject { |slot| (1..SLOT_COUNT).cover?(slot) }
  unless invalid.empty?
    raise OptionParser::InvalidArgument,
          "slot must be between 1 and #{SLOT_COUNT}: #{invalid.join(', ')}"
  end

  slots.uniq.sort
end

options = {
  slots: nil,
  output: nil,
  force: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{File.basename($PROGRAM_NAME)} [options] SaveRAM-file"

  opts.on("-o", "--output PATH", "output path (default: *.crc-fixed.SaveRAM)") do |path|
    options[:output] = path
  end

  opts.on("-s", "--slots LIST", "slots to repair, for example 1 or 1,3") do |value|
    options[:slots] = parse_slots(value)
  end

  opts.on("-f", "--force", "skip magic and format-value checks") do
    options[:force] = true
  end

  opts.on("-h", "--help", "show this help") do
    puts opts
    exit
  end
end

begin
  parser.parse!
  raise OptionParser::MissingArgument, "SaveRAM-file" unless ARGV.length == 1
rescue OptionParser::ParseError => e
  warn "Error: #{e.message}"
  warn parser
  exit 2
end

input_path = ARGV.first
extension = File.extname(input_path)
stem = extension.empty? ? input_path : input_path[0...-extension.length]
output_path = options[:output] || "#{stem}#{extension}"

#if File.expand_path(input_path) == File.expand_path(output_path)
#  warn "Error: input and output paths are identical; specify a separate output path"
#  exit 2
#end

begin
  data = File.binread(input_path)
rescue SystemCallError => e
  warn "Error: cannot read #{input_path}: #{e.message}"
  exit 1
end

unless data.bytesize == SAVE_SIZE
  warn format("Error: expected a 0x%X-byte SaveRAM, but got 0x%X bytes",
              SAVE_SIZE, data.bytesize)
  exit 1
end

unless options[:force]
  signature = data.byteslice(4, 14)
  master_magic = read_u32(data, 0x18)
  master_size = read_u32(data, 0x1c)

  unless signature == "INAZUMA_ELEVEN" &&
         master_magic == EXPECTED_MAGIC && master_size == MASTER_HEADER_SIZE
    warn "Error: the master header is not an Inazuma Eleven (YEEJ) SaveRAM"
    warn "Use --force only if the file and its layout are known to be correct."
    exit 1
  end
end

# With no --slots option, repair slots marked as present at master +0x24..+0x26.
slots = options[:slots] || (1..SLOT_COUNT).select do |slot|
  data.getbyte(0x24 + slot - 1) != 0
end

if slots.empty?
  warn "Error: no active save slots were found; specify --slots or --force --slots"
  exit 1
end

unless options[:force]
  slots.each do |slot|
    slot_offset = MASTER_HEADER_SIZE + (slot - 1) * SLOT_SIZE
    magic = read_u32(data, slot_offset + 0x08)
    logical_size = read_u32(data, slot_offset + 0x0c)
    next if magic == EXPECTED_MAGIC && logical_size == EXPECTED_DATA_SIZE

    warn format("Error: slot %d has unexpected magic/size (%08x/%08x)",
                slot, magic, logical_size)
    warn "Use --force only if the slot layout is known to be correct."
    exit 1
  end
end

changes = []

slots.each do |slot|
  slot_offset = MASTER_HEADER_SIZE + (slot - 1) * SLOT_SIZE
  payload_crc_offset = slot_offset + 0x04
  payload_offset = slot_offset + SLOT_HEADER_SIZE

  old_payload_crc = read_u32(data, payload_crc_offset)
  new_payload_crc = game_crc32(data.byteslice(payload_offset, SLOT_PAYLOAD_SIZE))
  write_u32(data, payload_crc_offset, new_payload_crc)

  # The header CRC includes the payload CRC field, so it must be calculated
  # only after writing the new payload CRC.
  old_header_crc = read_u32(data, slot_offset)
  new_header_crc = game_crc32(data.byteslice(slot_offset + 0x04, 0x7c))
  write_u32(data, slot_offset, new_header_crc)

  changes << [slot, old_payload_crc, new_payload_crc,
              old_header_crc, new_header_crc]
end

# Recalculate this even when unchanged, so every CRC field selected by this
# tool is force-written from the current contents.
old_master_crc = read_u32(data, 0x00)
new_master_crc = game_crc32(data.byteslice(0x04, MASTER_HEADER_SIZE - 4))
write_u32(data, 0x00, new_master_crc)

begin
  File.binwrite(output_path, data)
rescue SystemCallError => e
  warn "Error: cannot write #{output_path}: #{e.message}"
  exit 1
end

#puts "Wrote: #{output_path}"
#puts format("Master CRC: %08x -> %08x%s", old_master_crc, new_master_crc,
#            old_master_crc == new_master_crc ? " (unchanged)" : "")
changes.each do |slot, old_payload, new_payload, old_header, new_header|
  #puts format("Slot %d payload CRC: %08x -> %08x%s",
  #            slot, old_payload, new_payload,
  #            old_payload == new_payload ? " (unchanged)" : "")
  #puts format("Slot %d header  CRC: %08x -> %08x%s",
  #            slot, old_header, new_header,
  #            old_header == new_header ? " (unchanged)" : "")
end
