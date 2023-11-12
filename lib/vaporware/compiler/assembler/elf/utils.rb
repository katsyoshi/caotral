module Vaporware::Compiler::Assembler::ELF::Utils
  def build = bytes.flatten.pack("C*")
  def size = build.bytesize
  def set! = (raise Vaporware::Compiler::Assembler::ELF::Error, "should be implement #{self.class}")

  private
  def align(val, bytes) = (val << 0 until val.size % bytes == 0)
  def bytes = (raise Vaporware::Compiler::Assembler::ELF::Error, "should be implement #{self.class}")
  def num2bytes(val, bytes) = hexas(val, bytes*2).reverse
  def check(val, bytes) = ((val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes) || (val.is_a?(Integer) && (hexas(val, bytes*2).size == bytes)))
  def hexas(val, hex) = ("%0#{hex}x" % val).split(/.{1,2/).map { |v| v.to_i(16) }
end
