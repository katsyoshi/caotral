class Vaporware::Assembler::ELF::Section::Strtab
  include Vaporware::Assembler::ELF::Utils
  def initialize(names = "\0main\0", **opts) = @names = names
  def build = @names.bytes.pack("C*")
end
