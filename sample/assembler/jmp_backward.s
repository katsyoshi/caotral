  .intel_syntax noprefix
  .globl main
main:
  push rbp
  mov rbp, rsp
  push 1
.Ltarget0:
  push 2
  jmp .Ltarget0
  pop rax
  mov rsp, rbp
  pop rbp
  ret
