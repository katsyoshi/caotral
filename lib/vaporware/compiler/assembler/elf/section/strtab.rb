class Vaporware::Compiler::Assembler::ELF::Section::Strtab
  attr_reader :bytes
  def initialize(name = "\0main\0") = @bytes = name

  def build = @bytes.bytes.pack("C*")
end
