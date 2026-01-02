extern int foo(int);
int foo(int x) { return x + 1; }

int main(void) {
  asm volatile(
               ".long foo-.-4\n"
               ".reloc .-4, R_X86_64_PC32, foo"
               );
  return 0;
}
