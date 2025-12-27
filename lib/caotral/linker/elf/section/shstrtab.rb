class Caotral::Linker::ELF::Section::Shstrtab
  include Caotral::Assembler::ELF::Utils
  def initialize(**opts) = @name = []
  def build = bytes.flatten.pack("C*")
  def set!(name:) = (@name << name!(name); self)
end
