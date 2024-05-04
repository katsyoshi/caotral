require "vaporware"
require "test/unit"

class Vaporware::Compiler::Assembler::ELF::Section::TestSymtab < Test::Unit::TestCase
  def setup = @symtab = Vaporware::Compiler::Assembler::ELF::Section::Symtab.new

  def test_default_values
    binary = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".force_encoding("ASCII-8BIT")
    assert_equal(@symtab.build, binary)
  end

  def test_main_value
    binary = "\x01\x00\x02\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".force_encoding("ASCII-8BIT")
    @symtab.set!(name: [1, 0, 2, 1])
    assert_equal(@symtab.build, binary)
    @symtab.set!(name: 16908289)
    assert_equal(@symtab.build, binary)
    @symtab.set!(name: "\x01\x00\x02\x01".force_encoding("ASCII-8BIT"))
    assert_equal(@symtab.build, binary)
  end
end
