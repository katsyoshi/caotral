module Caotral
  class Linker
    class ELF
      class Header
        include Caotral::Assembler::ELF::Utils
        attr_reader :entry, :phoffset, :shoffset, :shnum, :shstrndx
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

        def set!(entry: nil, phoffset: nil, shoffset: nil, shnum: nil, shstrndx: nil, phsize: nil, phnum: nil, ehsize: nil)
          @entry = num2bytes(entry, 8) if check(entry, 8)
          @phoffset = num2bytes(phoffset, 8) if check(phoffset, 8)
          @phsize = num2bytes(phsize, 2) if check(phsize, 2)
          @phnum = num2bytes(phnum, 2) if check(phnum, 2)
          @ehsize = num2bytes(ehsize, 2) if check(ehsize, 2)
          @shoffset = num2bytes(shoffset, 8) if check(shoffset, 8)
          @shnum = num2bytes(shnum, 2) if check(shnum, 2)
          @shstrndx = num2bytes(shstrndx, 2) if check(shstrndx, 2)
        end

        def ehsize = get(:ehsize)
        def phsize = get(:phsize)
        def phnum = get(:phnum)
        def shentsize = get(:shentsize)
        def shnum = get(:shnum)
        def shstrndx = get(:shstrndx)

        LONG_TYPES = %w[entry phoffset shoffset].freeze
        INT_TYPES = %w[type version].freeze
        SHORT_TYPES = %w[ehsize phsize phnum shentsize shnum shstrndx].freeze
        CHAR_TYPES = %w[arch flags].freeze
        private_constant :LONG_TYPES, :INT_TYPES, :SHORT_TYPES, :CHAR_TYPES

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

        def get(type)
          val = instance_variable_get(:"@#{type.to_s}").pack("C*")
          case type.to_s.downcase
          when *LONG_TYPES; val.unpack("Q<")
          when *INT_TYPES; val.unpack("L<")
          when *SHORT_TYPES; val.unpack("S<")
          when *CHAR_TYPES; val.unpack("C<")
          else
            raise "not specified: #{type}"
          end.first
        end
      end
    end
  end
end
