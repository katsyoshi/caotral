module Vaporware::Compiler::Assembler::ELF::Utils
  def build = bytes.flatten.pack("C*")
  def size = build.bytesize
  def set! = (raise Vaporware::Compiler::Assembler::ELF::Error, "should be implement #{self.class}")
  def empties = must_be_filled_section_fields

  private
  def align(val, bytes) = (val << 0 until val.size % bytes == 0)
  def bytes = (raise Vaporware::Compiler::Assembler::ELF::Error, "should be implement #{self.class}")
  def must_be_filled_section_fields = instance_variables.reject { |i| instance_variable_get(i) }
  def num2bytes(val, bytes) = hexas(val, bytes).reverse
  def check(val, bytes) = ((val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes) || (val.is_a?(Integer) && (hexas(val, bytes).size == bytes)))
  def hexas(val, hex) = ("%0#{hex*2}x" % val).scan(/.{1,2}/).map { |v| v.to_i(16) }.then { |list| list.unshift(0) until list.size >= hex; list }
end
