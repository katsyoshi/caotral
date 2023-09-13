class Vaporware::Compiler::Assembler::ELF::Section::Strtab

  def build = bytes.flatten.pack("C*")
  private
  def bytes = []
end
