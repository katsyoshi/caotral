require "caotral"
require "test/unit"

class Caotral::Assembler::ELF::Section::NoteTest < Test::Unit::TestCase
  def reference_binary = "\x04\x00\x00\x00 \x00\x00\x00\x05\x00\x00\x00GNU\x00\x02\x00\x01\xC0\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01\xC0\x04\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00".force_encoding("ASCII-8BIT")
  def setup = @note = Caotral::Assembler::ELF::Section::Note.new

  def test_gnu_property!
    assert_equal(
      Caotral::Assembler::ELF::Section::Note.gnu_property,
      reference_binary
    )
    assert_equal(
      @note.gnu_property!.build,
      reference_binary
    )
  end
end
