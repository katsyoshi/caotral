  .intel_syntax noprefix
  .globl main
main:
  push rbp
  mov rbp, rsp
  sub rsp, 0
  push 0
  pop rax
  push rax
  cmp rax, 0
  je .Lelse0
  push 1
  pop rax
  mov rsp, rbp
  pop rbp
  ret
  jmp .Lend0
.Lelse0:
  push 2
  pop rax
  mov rsp, rbp
  pop rbp
  ret
.Lend0:
  mov rsp, rbp
  pop rbp
  ret
