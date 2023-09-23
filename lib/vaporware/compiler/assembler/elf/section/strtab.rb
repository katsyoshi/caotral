class Vaporware::Compiler::Assembler::ELF::Section::Strtab
  include Vaporware::Compiler::Assembler::ELF::Utils
  def initialize(names = "\0main\0") = @names = names
  def build = @names.bytes.pack("C*")
end
