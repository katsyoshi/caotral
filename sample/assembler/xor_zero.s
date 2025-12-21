  .intel_syntax noprefix
  .globl main
main:
  push rbp
  mov rbp, rsp
  xor rax, rax
  mov rsp, rbp
  pop rbp
  ret
