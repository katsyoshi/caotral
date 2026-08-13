.section .rodata
.balign 16
.fill 9216, 1, 0x41

.text
.globl main
.type main, @function
main:
  mov $42, %eax
  ret
