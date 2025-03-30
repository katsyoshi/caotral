require "vaporware"
require "test/unit"

class Vaporware::Compiler::Assembler::ELF::Section::TestShstrtab < Test::Unit::TestCase
  def setup = @shstrtab = Vaporware::Compiler::Assembler::ELF::Section::Shstrtab.new
  def test_set_values
    binary = "\x00.text\x00".force_encoding("ASCII-8BIT")
    @shstrtab.set!(name: "text")
    assert_equal(@shstrtab.build, binary)
    binary = "\x00.text\x00.strtab\x00".force_encoding("ASCII-8BIT")
    @shstrtab.set!(name: "strtab")
    assert_equal(@shstrtab.build, binary)
  end
  def test_alert_values
    assert_raise(Vaporware::Compiler::Assembler::ELF::Error) { @shstrtab.set!(name: :main) }
    assert_raise(Vaporware::Compiler::Assembler::ELF::Error) { @shstrtab.set!(name: 123) }
  end
end
