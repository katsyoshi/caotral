.text
.globl main
.type main, @function
main:
  call aligned_function
  ret
.size main, .-main

.section .rodata
.globl prefix_rodata
.type prefix_rodata, @object
prefix_rodata:
  .byte 0x11
.size prefix_rodata, .-prefix_rodata

.data
.globl prefix_data
.type prefix_data, @object
prefix_data:
  .byte 0x22
.size prefix_data, .-prefix_data
