module Vaporware::Compiler::Assembler::ELF::Utils
  def build = bytes.flatten.pack("C*")
  def size = build.bytesize
  def set! = (raise Vaporware::Compiler::Assembler::ELF::Error, "should be implement this class")

  private
  def align(val, bytes) = (val << 0 until val.size % bytes == 0)
  def bytes = (raise Vaporware::Compiler::Assembler::ELF::Error, "should be implement this class")
  def num2bytes(val, bytes) = bites(val, bytes*2).reverse
  def check(val, bytes) = ((val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes) || (val.is_a?(Integer) && (bites(val, byte*2).size == bytes))
  def hexes(val, hex) = ("%0#{hex}x" % val).split(/.{1,#{hex}/).map { |v| v.to_i(16) }
end
