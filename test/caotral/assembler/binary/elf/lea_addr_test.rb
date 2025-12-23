require "caotral"
require "test/unit"
require "pathname"

class ELFLeaTest < Test::Unit::TestCase
  def test_lea_addr
    input = Pathname.pwd.join("sample", "assembler", "lea_addr.s").to_s
    output = "lea_addr.o"

    assembler = Caotral::Assembler.new(input:, output:)
    _header, _null, text, = assembler.to_elf

    expected = [
      0x55,
      0x48, 0x89, 0xe5,
      0x48, 0x83, 0xEC, 0x08,
      0x48, 0x8D, 0x45, 0xF8,
      0x48, 0x89, 0xec,
      0x5d,
      0xc3,
    ]

    assert_equal(expected, text.unpack("C*")[...expected.size])
  ensure
    File.delete(output) if File.exist?(output)
  end
end
