class Vaporware::Assembler::ELF::Section::Null
  include Vaporware::Assembler::ELF::Utils
  def initialize(**opts) = nil
  def build = bytes.flatten.pack("C*")
  def set! = self
  private def bytes = []
end
