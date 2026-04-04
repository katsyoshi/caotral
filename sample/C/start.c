typedef unsigned long size_t;

extern long write(int fd, const void *buf, size_t count);
extern void _exit(int status);

void _start(void) {
  static const char msg [] = "hello, world!!!\n";
  write(1, msg, sizeof(msg) - 1);
  _exit(0);
}
