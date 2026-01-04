require "caotral/binary/elf/utils"
class Caotral::Assembler::ELF::Section::BSS
  include Caotral::Binary::ELF::Utils
  def initialize(**opts) = nil
  def build = bytes.flatten.pack("C*")
  def set! = self

  private
  def bytes = []
  def check(val, bytes) = false
end
