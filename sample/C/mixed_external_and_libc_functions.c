extern int value_from_b(void);
extern int puts(const char *);

int main(void) {
  puts("hello, glibc");
  return value_from_b();
}
