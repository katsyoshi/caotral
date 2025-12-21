  .intel_syntax noprefix
  .globl main
main:
  push rbp
  mov rbp, rsp
  jmp .Ltarget0
  push 1
.Ltarget0:
  push 2
  pop rax
  mov rsp, rbp
  pop rbp
  ret
