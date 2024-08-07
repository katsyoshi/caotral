class Vaporware::Compiler::Assembler::ELF::Section::BSS
  include Vaporware::Compiler::Assembler::ELF::Utils
  def initialize(**opts) = nil
  def build = bytes.flatten.pack("C*")
  def set! = self

  private
  def bytes = []
  def check(val, bytes) = false
end
