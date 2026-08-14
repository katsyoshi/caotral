.section .bss
.balign 8
.globl value
.type value, @object
.size value, 8
value:
  .zero 8

.text
.globl _start
.type _start, @function
_start:
  movq $42, value(%rip)
  movq value(%rip), %rdi
  movq $60, %rax
  syscall
