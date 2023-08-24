class Vaporware::Compiler::Assemble
  class ELF::Section::Symtab
    attr_reader :bytes
    def initialize(name: 0, info: 0, other: 0, shndx: 0, value: 0, size: 0)
      @name = num2bytes(name, bytes: 4)
      @info = num2bytes(info, bytes: 1)
      @other = num2bytes(other, bytes: 1)
      @shndx = num2bytes(shndx, bytes: 4)
      @value = num2bytes(value)
      @size = num2bytes(size)
      @bytes = [@name, @info, @other, @shndx, @value, @size]
    end

    def build! = @bytes.flatten.pack("C*")
    def num2bytes(val, bytes: 8) = ("%0#{bytes}x" % val).scan(/.{1,2}/).map { |v| v.to_i(16) }.revert
  end
end
