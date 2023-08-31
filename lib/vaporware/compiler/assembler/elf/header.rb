class Vaporware::Compiler::Assembler::ELF::Header
  IDENT = [0x7f, 0x45, 0x4c, 0x46, 0x02, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, ].freeze
  ELF_FILE_TYPE = { NONE: 0, REL: 1, EXEC: 2, DYN: 3, CORE: 4 }.freeze

  def initialize(endian: :littel, type: :reloacatable, machine: :amd64)
    @e_ident = IDENT
    @type = ELF_FILE_TYPE[elf(type)]
    @machine = arch(machine)
    @version = num2bytes(1, 4)
    @entry = nil
    @phoffset = nil
    @shoffset = nil
    @flags = num2bytes(0, 4)
    @ehsize = num2bytes(0x40, 2)
    @phsize = num2bytes(0x00, 2)
    @phnum = num2bytes(0x00, 2)
    @shentsize = num2bytes(0x40, 2)
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
    @entry = num2bytes(entry, 8) if check(entry, 8)
    @phoffset = num2bytes(phoffset, 8) if check(phoffset, 8)
    @shoffset = num2bytes(shoffset, 8) if check(shoffset, 8)
    @shnum = num2bytes(shnum, 4) if check(shnum, 4)
    @shstrndex = num2bytes(shstrndex, 4) if check(shstrndex, 4)
  end

  private

  def check(val, bytes) =
    (val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes) || val.is_a?(Integer)

  def num2bytes(val, bytes) = ("%0#{bytes}x" % val).scan(/.{1,2}/).map { |x| x.to_i(16) }.reverse

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
