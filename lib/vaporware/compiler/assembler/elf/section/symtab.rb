class Vaporware::Compiler::Assembler::ELF::Section::Symtab
  include Vaporware::Compiler::Assembler::ELF::Utils
  def initialize
    @name = num2bytes(0, 4)
    @info = num2bytes(0, 1)
    @other = num2bytes(0, 1)
    @shndx = num2bytes(0, 2)
    @value = num2bytes(0, 8)
    @size = num2bytes(0, 8)
  end

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
end
