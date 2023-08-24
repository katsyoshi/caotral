class Vaporware::Compiler::Assembler::ELF
  class Header
    IDENT = [0x7f, 0x45, 0x4c, 0x46, 0x02, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, ].freeze
    ELF_FILE_TYPE = { NONE: 0, REL: 1, EXEC: 2, DYN: 3, CORE: 4 }.freeze

    def initialize(endian: :littel, type: :reloacatable, machine: :amd64)
      @e_ident = IDENT
      @type = ELF_FILE_TYPE[elf(type)]
      @machine = arch(machine)
      @version = [0x01, 0x00, 0x00, 0x00]
      @entry = nil
      @phoffset = nil
      @shoffset = nil
      @flags = [0x00,] * 4
      @ehsize = [0x40, 0x00]
      @phsize = [0x00, 0x00]
      @phnum = [0x00, 0x00]
      @shentsize = [0x40, 0x00]
      @shnum = nil
      @shstrndex = nil
    end

    def build!
      unless [@entry, @phoffset, @shoffset, @shentsize, @shnum, @shstrndex].all?
        raise Vaporware::Assembler::ELF::ERROR
      end
      [
        @e_ident, @type, @machine, @version, @entry, @phoffset,
        @shoffset, @flags, @ehsize, @phsize, @phnum, @shentsize,
        @shnum, @shstrndex
      ].flatten.pack("C*")
    end

    def set!(entry: nil, phoffset: nil, shoffset: nil, shnum: nil, shstrndex: nil)
      @entry = entry if check(entry, 8)
      @phoffset = phoffset if check(phoffset, 8)
      @shoffset = shoffset if check(shoffset, 8)
      @shnum = shnum if check(shnum, 4)
      @shstrndex = shstrndex if check(shstrndex, 4)
    end

    private

    def arch(machine)
      case machine.to_s
      in "amd64" | "x86_64" | "x64"
        [0x3e, 0x00]
      end
    end

    def check(val, bytes) =
      val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes

    def num2bytes(val, bytes: 4)
      ("%0#{bytes}x" % val).scan(/.{1,2}/).map { |x| x.to_i(16) }.then { |ret| @endian == :littel ? ret.reverse : ret }
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
