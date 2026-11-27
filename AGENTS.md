# Caotral

Caotral compiles a subset of Ruby to native code. The compiler emits x86-64 assembly, the assembler produces ELF object files, and the linker produces executables or shared objects. See `FEATURES/GOALS.md` and `FEATURES/LINKER.md` for project scope.

## Repository layout

- Implementation lives under `lib/caotral/`, with corresponding RBS declarations under `sig/caotral/`.
- Tests live under `test/`. Put source files used directly as compiler, assembler, or linker test inputs under `sample/`. Keep test assertions in `test/`.
- Run the suite from the repository root with `bundle exec rake test`. Run RBS type checks with `bundle exec rake steep:check`.

## Local workspace

`.local/` is reserved for local use. Contributors can use it for personal notes, tool configuration, and caches.

For personal Codex instructions, use `./.local/codex/AGENTS.md`. Codex should read this file if it exists.
