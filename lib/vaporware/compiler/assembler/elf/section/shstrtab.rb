class Vaporware::Compiler::Assembler::ELF::Section::Shstrtab
  include Vaporware::Compiler::Assembler::ELF::Utils
  def initialize = @strtab = []
  def build = bytes.flatten.pack("C*")
  def set!(name:) = @strtab << name
  private
  def bytes = [@strtab]
end
