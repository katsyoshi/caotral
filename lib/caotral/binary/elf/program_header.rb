require "caotral/binary/elf/utils"

module Caotral
  module Binary
    class ELF
      class ProgramHeader
        include Caotral::Binary::ELF::Utils
        PF_X = 1
        PF_W = 2
        PF_R = 4
        PF = {
          RWX: PF_R | PF_W | PF_X,
          RW: PF_R | PF_W,
          RX: PF_R | PF_X,
          WX: PF_W | PF_X,
          R: PF_R,
          W: PF_W,
          X: PF_X,
          NOP: 0,
        }.freeze
        PF_BY_V = PF.invert.freeze
        PT = {
          NULL: 0,
          LOAD: 1,
          DYNAMIC: 2,
          INTERP: 3,
        }.freeze
        PT_BY_V = PT.invert.freeze
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

        def type = PT_BY_V[@type.pack("C*").unpack1("L<")]
        def flags = PF_BY_V[@flags.pack("C*").unpack1("L<")]
        def offset = @offset.pack("C*").unpack1("Q<")
        def filesz = @filesz.pack("C*").unpack1("Q<")
        def memsz = @memsz.pack("C*").unpack1("Q<")
        def vaddr = @vaddr.pack("C*").unpack1("Q<")

        private def bytes = [@type, @flags, @offset, @vaddr, @paddr, @filesz, @memsz, @align]
      end
    end
  end
end
