class Vaporware::Compiler::Assembler::ELF::Section::BSS

  def build = bytes.flatten.pack("C*")
  private
  def bytes = []
end
