# Self Linker

## Purpose

The self linker is the minimal linker implementation required by Caotral's
[native-execution goals](GOALS.md). It is designed to link artifacts used by
that subsystem rather than to replace a general-purpose system linker.

The self linker is selected with `linker: "self"`. Other values delegate
linking to an external linker and are outside this specification.

## Supported Scope

### Inputs

- ELF64 x86-64 relocatable objects (`ET_REL`).
- Multiple input objects.
- Regular `ar` archives with a GNU 32-bit symbol table, supplied through
  `archives:`.
- GNU long archive member names stored through the `//` name table.
- Archive members are extracted on demand from the archive symbol table.
  Extraction is repeated until no newly extracted member introduces another
  resolvable dependency.

The linker merges `.text`, `.rodata`, `.data`, and `.bss` contributions while
preserving their alignment requirements.

### Output Modes

- A non-PIE executable (`ET_EXEC`).
- A position-independent executable (`ET_DYN`) with `pie: true`.
- A shared object (`ET_DYN`) with `shared: true`.
- A non-executable ELF image with `executable: false`; its entry point is zero.

`shared: true` and `pie: true` cannot be used together. Executable output uses
an input `_start` symbol when present. Otherwise, it emits a small entry stub
that calls `main` and exits with the returned status.

Allocated sections are placed in separate read-only, executable, and writable
`PT_LOAD` segments. PIE and shared-object outputs include the dynamic sections
needed for symbol lookup, runtime relocation, and PLT/GOT calls.

### Symbol Resolution

- Local symbols are scoped to their input object.
- A global symbol may have only one definition across the selected inputs.
  Duplicate global definitions are rejected.
- Global and weak definitions are exported through `.dynsym` in dynamic
  outputs.
- Undefined symbols in dynamic outputs can be resolved through the generated
  PLT and GOT entries.

The `needed:` option accepts shared-library names and emits one `DT_NEEDED`
entry for each value. These values are runtime dependency names only; the self
linker does not search the filesystem or interpret `-l` and `-L` options.

### Relocations

The implemented relocation paths are:

- `R_X86_64_PC32`
- `R_X86_64_PLT32`
- `R_X86_64_64`, lowered to `R_X86_64_RELATIVE` for dynamic output
- `R_X86_64_JUMP_SLOT`, generated for dynamic PLT entries

## Current Limitations

- Input compatibility is limited to the sections and relocations needed by the
  current native-execution subsystem; arbitrary ELF relocatable objects are
  not guaranteed to link.
- `R_X86_64_GOTPCREL`, `R_X86_64_GOTPCRELX`, and
  `R_X86_64_REX_GOTPCRELX` are rejected.
- PIE output uses the Linux x86-64 interpreter path
  `/lib64/ld-linux-x86-64.so.2`.
- The self linker does not perform library discovery or process linker scripts.
  `needed:` values are recorded as runtime dependency names only.
- Thin archives and the GNU 64-bit `/SYM64/` archive symbol table are not
  supported.
- The archive reader currently copies the complete archive into memory.

## Non-goal

Command-line compatibility with general-purpose linkers such as GNU ld, mold,
and LLD is not a goal. The self linker is driven through Caotral's Ruby API.
