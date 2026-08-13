.section .data
.align 8
ptr:
  .quad value
value:
  .quad 42
.section .text
.globl _start
_start:
  mov ptr(%rip), %rax
  mov (%rax), %rdi
  mov $60, %rax
  syscall

