require "vaporware"
require "test/unit"

class Vaporware::Compiler::Assembler::ELF::SectionHeaderTest < Test::Unit::TestCase
  def setup = @section_header = Vaporware::Compiler::Assembler::ELF::SectionHeader.new
  def test_null!
    assert(@section_header.null!)
    assert_equal(@section_header.build, [[0] * 4, [0] * 4, [0] * 8, [0] * 8, [0] * 8, [0] * 8, [0] * 4, [0] * 4, [0] * 8, [0] * 8].flatten.pack("C*"))
  end
end
