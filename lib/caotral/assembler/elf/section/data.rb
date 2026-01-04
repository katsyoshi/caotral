require "caotral/binary/elf/utils"
class Caotral::Assembler::ELF::Section::Data
  include Caotral::Binary::ELF::Utils
  def initialize(**opts) = nil
  def build = bytes.flatten.pack("C*")
  def set! = self
  private def bytes = []
end
