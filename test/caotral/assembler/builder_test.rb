require "caotral"
require "test/unit"
require "pathname"

class Caotral::Assembler::BuilderTest < Test::Unit::TestCase
  def test_build
    input = Pathname.pwd.join('sample', 'assembler', 'plus.s').to_s
    instructions = Caotral::Assembler::Reader.new(input:).read
    builder = Caotral::Assembler::Builder.new(instructions:).build
  
    assert_equal(0, builder.header.shoffset)
    assert_equal(8, builder.header.shnum)
    assert_equal(7, builder.header.shstrndx)
  end
end
