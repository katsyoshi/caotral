class Vaporware::Compiler::Assembler::ELF::Section::Note
  def self.gnu_property
    note = new
    note.gnu_property!
    note.build
  end
  def initialize
    @nsize = nil
    @dsize = nil
    @type = nil
    @name = nil
    @desc = nil
  end

  def set!(nsize: nil, dsize: nil, type: nil, name: nil, desc: nil)
    @nsize = num2bytes(nsize, 4) if check(nsize, 4)
    @dsize = num2bytes(dsize, 4) if check(disze, 4)
    @type = num2bytes(type, 4) if check(type, 4)
    @name = name!(name) if name
    @desc = desc!(desc) if desc
  end

  def gnu_property! = set!(nsize: 0x04, dsize: 0x20, type: 0x05, name: "GNU", desc: %w(02 00 01 c0 04 00 00 00 00 00 00 00 00 00 00 00 01 00 01 c0 04 00 00 00 01 00 00 00 00 00 00 00).map { |val| val.to_i(16) })

  def build = bytes.flatten.pack("C*")

  private
  def name!(name) = align!(@name = name.bytes, 4)
  def desc!(desc) = align!(@desc = desc.bytes, 4)

  def bytes = [@nsize, @dsize, @type, @name, @desc]
  def align!(val, bytes) = (val << 0 until val.size % bytes == 0)
  def num2bytes(val, bytes) = ("%0#{bytes}x" % val).scan(/.{1,2}/).map { |v| v.to_i(16) }.revert
  def check(val, bytes) = (val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes) || val.is_a?(Integer)
end
