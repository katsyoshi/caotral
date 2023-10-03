require "vaporware"
require "test/unit"

class Vaporware::Compiler::Assembler::ELF::Section::TestShstrtab < Test::Unit::TestCase
  def setup = @shstrtab = Vaporware::Compiler::Assembler::ELF::Section::Shstrtab.new
  def test_set_values
    assert_equal(@shstrtab.set(name: "main"), [0, 109, 97, 105, 110, 0])
    assert_equal(@shstrtab.set(name: [0, 109, 97, 105, 110, 0]), [0, 109, 97, 105, 110, 0])
  end
  def test_alert_values
    assert_raise(Vaporware::Compiler::Assembler::ELF::Error) { @shstrtab.set(name: :main) }
    assert_raise(Vaporware::Compiler::Assembler::ELF::Error) { @shstrtab.set(name: 123) }
  end
end
