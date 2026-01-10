require_relative "utils"
module Caotral
  module Binary
    class ELF
      class Header
        include Caotral::Binary::ELF::Utils
        IDENT = [0x7f, 0x45, 0x4c, 0x46, 0x02, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00].freeze
        IDENT_STR = IDENT.pack("C*").freeze
        ELF_FILE_TYPE = { NONE: 0, REL: 1, EXEC: 2, DYN: 3, CORE: 4 }.freeze

        def initialize(endian: :little, type: :rel, arc: :amd64)
          @ident = IDENT
          @type = num2bytes(ELF_FILE_TYPE[elf(type)], 2)
          @arch = arch(arc)
          @version = num2bytes(1, 4)
          @entry = num2bytes(0x00, 8)
          @phoffset = num2bytes(0x00, 8)
          @shoffset = num2bytes(0x00, 8)
          @flags = num2bytes(0x00, 4)
          @ehsize = num2bytes(0x40, 2)
          @phsize = num2bytes(0x00, 2)
          @phnum = num2bytes(0x00, 2)
          @shentsize = num2bytes(0x40, 2)
          @shnum = num2bytes(0x08, 2)
          @shstrndx = num2bytes(0x07, 2)
        end

        def build = bytes.flatten.pack("C*")

        def set!(type: nil, entry: nil, phoffset: nil, shoffset: nil, shnum: nil, shstrndx: nil, phsize: nil, phnum: nil, ehsize: nil)
          @type = num2bytes(type, 2) if check(type, 2)
          @entry = num2bytes(entry, 8) if check(entry, 8)
          @phoffset = num2bytes(phoffset, 8) if check(phoffset, 8)
          @phsize = num2bytes(phsize, 2) if check(phsize, 2)
          @phnum = num2bytes(phnum, 2) if check(phnum, 2)
          @ehsize = num2bytes(ehsize, 2) if check(ehsize, 2)
          @shoffset = num2bytes(shoffset, 8) if check(shoffset, 8)
          @shnum = num2bytes(shnum, 2) if check(shnum, 2)
          @shstrndx = num2bytes(shstrndx, 2) if check(shstrndx, 2)
          self
        end

        def entry = @entry.pack("C*").unpack1("Q<")
        def ehsize = @ehsize.pack("C*").unpack1("S<")
        def phsize = @phsize.pack("C*").unpack1("S<")
        def phnum = @phnum.pack("C*").unpack1("S<")
        def shentsize = @shentsize.pack("C*").unpack1("S<")
        def shnum = @shnum.pack("C*").unpack1("S<")
        def shstrndx = @shstrndx.pack("C*").unpack1("S<")
        def shoffset = @shoffset.pack("C*").unpack1("Q<")

        private
        def bytes = [
          @ident, @type, @arch, @version, @entry, @phoffset,
          @shoffset, @flags, @ehsize, @phsize, @phnum, @shentsize,
          @shnum, @shstrndx
        ]

        def arch(machine)
          case machine.to_s
          in "amd64" | "x86_64" | "x64"
            [0x3e, 0x00]
          end
        end

        def elf(type)
          case type.to_s
          in "relocatable" | "rel"
            :REL
          in "exe" | "ex" | "exec"
            :EXEC
          in "shared" | "share" | "dynamic" | "dyn"
            :DYN
          else
            :NONE
          end
        end
      end
    end
  end
end
