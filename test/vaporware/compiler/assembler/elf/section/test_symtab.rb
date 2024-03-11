require "vaporware"
require "test/unit"

class Vaporware::Compiler::Assembler::ELF::Section::TestSymtab < Test::Unit::TestCase
  def setup = @symtab = Vaporware::Compiler::Assembler::ELF::Section::Symtab.new
  def test_set_values
    binary = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x10\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".force_encoding("ASCII-8BIT")
    assert_equal(@symtab.build.size, binary.size)
  end
end
