require "vaporware"
require "test/unit"
require "tempfile"

class Vaporware::Compiler::Assembler::ELFTest < Test::Unit::TestCase
  def reference_binary = ""

  def test_to_elf
    input_file = Tempfile.open(["amd64.s"])
    input_file.puts <<~AMD64ASM
  .intel_syntax noprefix
  .globl main
main:
  push rbp
  mov rbp, rsp
  sub rsp, 0
  push 1
  push 2
  pop rdi
  pop rax
  add rax, rdi
  push rax
  push 3
  pop rdi
  pop rax
  imul rax, rdi
  push rax
  push 5
  push 4
  pop rdi
  pop rax
  sub rax, rdi
  push rax
  pop rdi
  pop rax
  cqo
  idiv rdi
  push rax
  mov rsp, rbp
  pop rbp
  ret
    AMD64ASM
    input = input_file.path

    assembler = Vaporware::Compiler::Assembler.new(input:, output: "amd64.o")
    assembler.to_elf
    binding.irb
  end
end
