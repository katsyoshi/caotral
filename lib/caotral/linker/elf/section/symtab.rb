class Caotral::Linker::ELF::Section::Symtab
  include Caotral::Assembler::ELF::Utils
  def initialize(**opts)
    @entsize = []
    @name = num2bytes(0, 4)
    @info = num2bytes(0, 1)
    @other = num2bytes(0, 1)
    @shndx = num2bytes(0, 2)
    @value = num2bytes(0, 8)
    @size = num2bytes(0, 8)
  end
end
