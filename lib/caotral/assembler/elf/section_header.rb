class Caotral::Assembler::ELF::SectionHeader
  include Caotral::Assembler::ELF::Utils
  def initialize
    @name = nil
    @type = nil
    @flags = nil
    @addr = nil
    @offset = nil
    @size = nil
    @link = nil
    @info = nil
    @addralign = nil
    @entsize = nil
  end

  def build = bytes.flatten.pack("C*")

  def set!(name: nil, type: nil, flags: nil, addr: nil,
           offset: nil, size: nil, link: nil, info: nil,
           addralign: nil, entsize: nil)
    @name = num2bytes(name, 4) if check(name, 4)
    @type = num2bytes(type, 4) if check(type, 4)
    @flags = num2bytes(flags, 8)  if check(flags, 8)
    @addr = num2bytes(addr, 8) if check(addr, 8)
    @offset = num2bytes(offset, 8) if check(offset, 8)
    @size = num2bytes(size, 8) if check(size, 8)
    @link = num2bytes(link, 4) if check(link, 4)
    @info = num2bytes(info, 4) if check(info, 4)
    @addralign = num2bytes(addralign, 8) if check(addralign, 8)
    @entsize = num2bytes(entsize, 8) if check(entsize, 8)
    self
  end

  def null! = set!(name: 0, type: 0, flags: 0, addr: 0, offset: 0, size: 0, link: 0, info: 0, addralign: 0, entsize: 0)
  def text! = set!(flags: 0x06, addralign: 0x01, addr: 0, type: 1, entsize: 0, link: 0, info: 0)
  def data! = set!(type: 0x01, flags: 0x03, addralign: 1, addr: 0, info: 0, link: 0, entsize: 0)
  def bss! = set!(type: 0x8, flags: 3, addralign: 1, addr: 0, info: 0, link: 0, entsize: 0)
  def note! = set!(type: 0x07, flags: 0x02, size: 0x30, addralign: 0x08, addr: 0, link: 0, info: 0, entsize: 0)
  def symtab! = set!(type: 2, info: 1, addr: 0, link: 6, entsize: 0x18, addralign: 8, flags: 0)
  def strtab! = set!(type: 3, info: 0, addr: 0, link: 0, entsize: 0, addralign: 1, flags: 0)
  def shstrtab! = set!(type: 3, info: 0, addr: 0, link: 0, entsize: 0, addralign: 1, flags: 0)

  private def bytes = [@name, @type, @flags, @addr, @offset, @size, @link, @info, @addralign, @entsize]
end
