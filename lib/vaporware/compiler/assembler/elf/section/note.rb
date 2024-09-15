class Vaporware::Compiler::Assembler::ELF::Section::Note
  include Vaporware::Compiler::Assembler::ELF::Utils

  def self.gnu_property = new.gnu_property!.build
  def self.null = new.null!.build

  def initialize(type: nil)
    @nsize = nil
    @dsize = nil
    @type = nil
    @name = nil
    @desc = nil
    gnu_property! if type == :gnu
  end

  def set!(nsize: nil, dsize: nil, type: nil, name: nil, desc: nil)
    @nsize = num2bytes(nsize, 4) if check(nsize, 4)
    @dsize = num2bytes(dsize, 4) if check(dsize, 4)
    @type = num2bytes(type, 4) if check(type, 4)
    @name = name!(name) if name
    @desc = desc!(desc) if desc
    self
  end

  def gnu_property! = set!(nsize: 0x04, dsize: 0x20, type: 0x05, name: "GNU", desc: %w(02 00 01 c0 04 00 00 00 00 00 00 00 00 00 00 00 01 00 01 c0 04 00 00 00 01 00 00 00 00 00 00 00).map { |val| val.to_i(16) })
  def null! = set!(nsize: 0, dsize: 0, type: 0, name: "NULL", desc: [0])

  private

  def name!(name) = align(@name = name.bytes, 4)
  def desc!(desc) = align(@desc = desc.is_a?(Array) ? desc : desc.bytes, 4)
  def bytes = [@nsize, @dsize, @type, @name, @desc]
end
