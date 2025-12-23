require "caotral"
require "test/unit"
require "pathname"

class ELFXorTest < Test::Unit::TestCase
  def test_xor_zero
    input = Pathname.pwd.join("sample", "assembler", "xor_zero.s").to_s
    output = "xor_zero.o"

    assembler = Caotral::Assembler.new(input:, output:)
    _header, _null, text, = assembler.to_elf

    expected = [
      0x55, # push rbp
      0x48, 0x89, 0xe5, # mov rbp, rsp
      0x48, 0x31, 0xc0, # xor rax, rax
      0x48, 0x89, 0xec, # mov rsp, rbp
      0x5d, # pop rbp
      0xc3, # ret
    ]

    assert_equal(expected, text.unpack("C*")[...expected.size])
  ensure
    File.delete(output) if File.exist?(output)
  end
end
