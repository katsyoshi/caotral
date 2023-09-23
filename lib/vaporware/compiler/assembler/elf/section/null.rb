class Vaporware::Compiler::Assembler::ELF::Section::Null
  include Vaporware::Compiler::Assembler::ELF::Utils
  def initialize = nil
  def build = bytes.flatten.pack("C*")
  def set! = self
  private def bytes = []
end
