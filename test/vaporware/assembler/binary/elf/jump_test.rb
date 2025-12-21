require "vaporware"
require "test/unit"
require "pathname"

class ELFJumpTest < Test::Unit::TestCase
  def test_forward_jump
    input = Pathname.pwd.join("sample", "assembler", "jmp_forward.s").to_s
    output = "jmp_forward.o"

    assembler = Vaporware::Assembler.new(input:, output:)
    _header, _null, text, = assembler.to_elf

    expected = [
      0x55, # push rbp
      0x48, 0x89, 0xe5, # mov rbp, rsp
      0xe9, 0x02, 0x00, 0x00, 0x00, # jmp .Ltarget0
      0x6a, 0x01, # push 1
      0x6a, 0x02, # push 2
      0x58, # pop rax
      0x48, 0x89, 0xec, # mov rsp, rbp
      0x5d, # pop rbp
      0xc3, # ret
    ]

    assert_equal(expected, text.unpack("C*")[...expected.size])
  ensure
    File.delete(output) if File.exist?(output)
  end

  def test_backward_jump
    input = Pathname.pwd.join("sample", "assembler", "jmp_backward.s").to_s
    output = "jmp_backward.o"

    assembler = Vaporware::Assembler.new(input:, output:)
    _header, _null, text, = assembler.to_elf

    expected = [
      0x55, # push rbp
      0x48, 0x89, 0xe5, # mov rbp, rsp
      0x6a, 0x01, # push 1
      0x6a, 0x02, # push 2
      0xe9, 0xf9, 0xff, 0xff, 0xff, # jmp .Ltarget0
      0x58, # pop rax
      0x48, 0x89, 0xec, # mov rsp, rbp
      0x5d, # pop rbp
      0xc3, # ret
    ]

    assert_equal(expected, text.unpack("C*")[...expected.size])
  ensure
    File.delete(output) if File.exist?(output)
  end
end
