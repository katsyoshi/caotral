require "caotral/binary/elf/utils"
class Caotral::Assembler::ELF::Section::Strtab
  include Caotral::Binary::ELF::Utils
  def initialize(names = "\0main\0", **opts) = @names = names
  def build = @names.bytes.pack("C*")
end
