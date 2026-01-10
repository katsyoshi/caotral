require "caotral/binary/elf/utils"

module Caotral
  module Binary
    class ELF
      class ProgramHeader
        include Caotral::Binary::ELF::Utils
        def initialize
          @type = num2bytes(0, 4)
          @flags = num2bytes(0, 4)
          @offset = num2bytes(0, 8)
          @vaddr = num2bytes(0, 8)
          @paddr = num2bytes(0, 8)
          @filesz = num2bytes(0, 8)
          @memsz = num2bytes(0, 8)
          @align = num2bytes(0, 8)
        end
        def build = bytes.flatten.pack("C*")
        def set!(type: nil, flags: nil, offset: nil, vaddr: nil, paddr: nil, filesz: nil, memsz: nil, align: nil)
          @type = num2bytes(type, 4) if check(type, 4)
          @flags = num2bytes(flags, 4) if check(flags, 4)
          @offset = num2bytes(offset, 8) if check(offset, 8)
          @vaddr = num2bytes(vaddr, 8) if check(vaddr, 8)
          @paddr = num2bytes(paddr, 8) if check(paddr, 8)
          @filesz = num2bytes(filesz, 8) if check(filesz, 8)
          @memsz = num2bytes(memsz, 8) if check(memsz, 8)
          @align = num2bytes(align, 8) if check(align, 8)
          self
        end
        private def bytes = [@type, @flags, @offset, @vaddr, @paddr, @filesz, @memsz, @align]
      end
    end
  end
end
