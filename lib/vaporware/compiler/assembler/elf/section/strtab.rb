class Vaporware::Compiler::Assembler::ELF::Section::Strtab
  def initialize(names = "\0main\0") = @names = names
  def build = @names.bytes.pack("C*")
end
