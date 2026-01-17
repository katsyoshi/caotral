require "caotral/binary/elf/utils"

module Caotral
  module Binary
    class ELF
      class Section
        class Symtab
          include Caotral::Binary::ELF::Utils
          attr_accessor :name_string
          def initialize(**opts)
            @entsize = []
            @name = num2bytes(0, 4)
            @info = num2bytes(0, 1)
            @other = num2bytes(0, 1)
            @shndx = num2bytes(0, 2)
            @value = num2bytes(0, 8)
            @size = num2bytes(0, 8)
            @name_string = ""
          end
          def build = bytes.flatten.pack("C*")

          def set!(name: nil, info: nil, other: nil, shndx: nil, value: nil, size: nil)
            @name = num2bytes(name, 4) if check(name, 4)
            @info = num2bytes(info, 1) if check(info, 1)
            @other = num2bytes(other, 1) if check(other, 1)
            @shndx = num2bytes(shndx, 2) if check(shndx, 2)
            @value = num2bytes(value, 8) if check(value, 8)
            @size = num2bytes(size, 8) if check(size, 8)
            self
          end

          def name_offset = @name.pack("C*").unpack1("L<")
          def value = @value.pack("C*").unpack1("Q<")
          def info = @info.pack("C*").unpack1("C")
          def shndx = @shndx.pack("C*").unpack1("S<")
          def bind = info >> 4
          def type = info & 0x0f

          private def bytes = [@name, @info, @other, @shndx, @value, @size]
        end
      end
    end
  end
end
