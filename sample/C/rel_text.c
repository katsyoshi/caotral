extern int foo(void);
int foo(void) { return 0; }

int main(void) {
  asm volatile(
               "jmp 1f\n"
               ".long 0\n"
               ".reloc .-4, R_X86_64_PC32, foo\n"
               "1:\n"
               );
  return foo();
}
