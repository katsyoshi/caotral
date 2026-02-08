#include <stdint.h>

extern int foo;

uintptr_t get_addr(void) {
  uintptr_t x;
  __asm__ volatile ("movabs $foo, %0" : "=r"(x));
  return x;
}

int foo = 42;

int main(void) {
  return (int)get_addr();
}
