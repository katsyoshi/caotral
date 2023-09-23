module Vaporware::Compiler::Assembler::ELF::Utils
  def build = bytes.flatten.pack("C*")
  def size = build.bytesize

  private

  def align(val, bytes) = (val << 0 until val.size % bytes == 0)
  def bytes = (raise Vaporware::Error, "should be implement this class")
  def num2bytes(val, bytes) = ("%0#{bytes}x" % val).scan(/.{1,2}/).map { |v| v.to_i(16) }.reverse
  def check(val, bytes) = (val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes) || val.is_a?(Integer)
end
