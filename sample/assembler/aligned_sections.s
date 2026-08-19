.text
.balign 32
.globl aligned_function
.type aligned_function, @function
aligned_function:
  mov aligned_rodata(%rip), %eax
  add aligned_data(%rip), %eax
  ret
.size aligned_function, .-aligned_function

.section .rodata
.balign 32
.globl aligned_rodata
.type aligned_rodata, @object
aligned_rodata:
  .long 40
.size aligned_rodata, .-aligned_rodata

.data
.balign 32
.globl aligned_data
.type aligned_data, @object
aligned_data:
  .long 2
.size aligned_data, .-aligned_data
