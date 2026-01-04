require "caotral/binary/elf/utils"
class Caotral::Assembler::ELF::Section::Symtab
  include Caotral::Binary::ELF::Utils
  def initialize(**opts)
    @entsize = []
    @name = num2bytes(0, 4)
    @info = num2bytes(0, 1)
    @other = num2bytes(0, 1)
    @shndx = num2bytes(0, 2)
    @value = num2bytes(0, 8)
    @size = num2bytes(0, 8)
  end

  def set!(entsize: nil, name: nil, info: nil, other: nil, shndx: nil, value: nil, size: nil)
    @entsize = [0] * entsize unless entsize.nil?
    @name = name2bytes(name, 4) if check(name, 4)
    @info = num2bytes(info, 1) if check(info, 1)
    @other = num2bytes(other, 1) if check(other, 1)
    @shndx = num2bytes(shndx, 2) if check(shndx, 2)
    @value = num2bytes(value, 8) if check(value, 8)
    @size = num2bytes(size, 8) if check(size, 8)
  end

  private
  def bytes = [@entsize, @name, @info, @other, @shndx, @value, @size]
  def name2bytes(name, bytes)
    case name
    when String
      name.bytes.reverse
    when Array
      name[0..bytes]
    when Integer
      num2bytes(name, bytes)
    else
      [0] * bytes
    end
  end
end
