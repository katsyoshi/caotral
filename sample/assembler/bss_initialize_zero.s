.section .bss
.balign 8
.zero 24

.globl value
.type value, @object
.size value, 8
value:
  .zero 8

.text
.globl _start
.type _start, @function
_start:
  cmpq $0, value(%rip)
  jne .Lnot_zero

  movq $42, value(%rip)
  movq value(%rip), %rdi
  jmp .Lexit

.Lnot_zero:
  movq $1, %rdi

.Lexit:
  movq $60, %rax
  syscall
