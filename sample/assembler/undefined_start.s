.text
.globl main
.type main, @function
main:
  mov $42, %eax
  ret
.size main, .-main

.weak _start

.data
  .long _start
