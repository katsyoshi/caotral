class Vaporware::Compiler::Assembler::ELF::SectionHeader
  include Vaporware::Compiler::Assembler::ELF::Utils
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
  def text! = set!(flags: 0x06, addralign: 0x01)
  def note! = set!(type: 0x07, flags: 0x02, size: 0x30, addralign: 0x08)
  def data! = set!()
  def symtab! = set!
  def strtab! = set!
  def bss! = set!
  def shsymtab! = set!
end
