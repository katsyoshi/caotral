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
