class Vaporware::Compiler::Assembler::ELF::Section::Symtab
  def initialize(name: 0, info: 0, other: 0, shndx: 0, value: 0, size: 0)
    @name = num2bytes(name, 4)
    @info = num2bytes(info, 1)
    @other = num2bytes(other, 1)
    @shndx = num2bytes(shndx, 4)
    @value = num2bytes(value, 8)
    @size = num2bytes(size, 8)
  end

  def build = bytes.flatten.pack("C*")

  def set!(name: nil, info: nil, other: nil, shndx: nil, value: nil, size: nil)
    @name = num2bytes(name, 4) if check(name, 4)
    @info = num2bytes(info, 1) if check(info, 4)
    @other = num2bytes(other, 1) if check(other, 1)
    @shndx = num2bytes(shndx, 4) if check(shndx, 4)
    @value = num2bytes(value, 8) if check(value, 8)
    @size = num2bytes(size, 8) if check(size, 8)
  end

  private
  def bytes = [@name, @info, @other, @shndx, @value, @size]
  def num2bytes(val, bytes) = ("%0#{bytes}x" % val).scan(/.{1,2}/).map { |v| v.to_i(16) }.reverse
  def check(val, bytes) = (val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes) || val.is_a?(Integer)
end
