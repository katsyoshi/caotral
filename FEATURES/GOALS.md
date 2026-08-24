# Project Goals

Caotral is an experimental native-execution toolchain for existing Ruby code.
Its primary direction is to provide another way to execute Ruby programs, not
to define a separate Ruby-like language.

The project aims to:

- Compile a supported subset of Ruby into native machine code.
- Produce native executables and ELF shared objects.
- Make compiled native code callable from Ruby.
- Keep the compiler independent from CRuby's VM-specific instruction sequence
  representation.
- Develop the assembler and self linker as low-level experimental subsystems
  while retaining the option to use the system toolchain.
