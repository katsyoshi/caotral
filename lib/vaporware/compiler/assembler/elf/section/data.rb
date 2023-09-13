class Vaporware::Compiler::Assembler::ELF::Section::Data

  def build = bytes.flatten.pack("C*")
  private
  def bytes = []
end
