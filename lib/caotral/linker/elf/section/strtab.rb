class Caotral::Linker::ELF::Section::Strtab
  include Caotral::Assembler::ELF::Utils
  def initialize(names = "\0main\0", **opts) = @names = names
  def build = @names.bytes.pack("C*")
end
