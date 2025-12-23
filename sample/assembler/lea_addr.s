  .intel_syntax noprefix
  .globl main
main:
  push rbp
  mov rbp, rsp
  sub rsp, 8
  lea rax, [rbp-8]
  mov rsp, rbp
  pop rbp
  ret
