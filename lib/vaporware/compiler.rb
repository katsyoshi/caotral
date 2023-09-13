# frozen_string_literal: true

require_relative "compiler/generator"
require_relative "compiler/assembler"

class Vaporware::Compiler
  def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
    _precompile = "#{dest}.s"
    s = new(input: source, output: _precompile, debug:, shared:)
    s.compile(compiler_options:)
    obj_file = s.assemble(input: _precompile, assembler: "as", debug:)
    output = File.basename(obj_file, ".o")
    output = "lib#{output}.so" if shared && output !~ /^lib.+\.so$/
    s.link(input: obj_file, output:, shared:)
    File.delete(obj_file) unless debug
    File.delete(_precompile) unless debug
  end

  def initialize(input:, output: File.basename(input, ".*") + ".s", debug: false, shared: false)
    @generator = Vaporware::Compiler::Generator.new(input:, output:, debug:, shared:)
    @assembler = Vaporware::Compiler::Assembler.new(input: @generator.precompile, debug:,)
  end

  def assemble(input:, output: File.basename(input, ".*") + ".o", assembler: "as", assembler_options: [], debug: false)
    if ["gcc", "as"].include?(assembler)
      assemble = [assembler, *assembler_options, "-o", output, input].compact
      call_command(assemble)
    else
      @assembler.assemble(input:, output:)
    end
    output
  end

  def link(input:, output: File.basename(input, ".*"), linker: "ld", linker_options: [], dyn_ld_path: ["-dynamic-linker", "/lib64/ld-linux-x86-64.so.2"], ld_path: ["/lib64/libc.so.6", "/usr/lib64/crt1.o"], shared: false)
    if shared
      dyn_ld_path = []
      ld_path = ["/usr/lib64/crti.o", "/usr/lib/gcc/x86_64-pc-linux-gnu/13/crtbeginS.o", "/usr/lib/gcc/x86_64-pc-linux-gnu/13/crtendS.o", "/usr/lib64/crtn.o",]

      linker_options = ["-shared"]
    end
    linker_commands = [linker, *linker_options, *dyn_ld_path, "-o", output, *ld_path, input].compact
    call_command(linker_commands)
  end

  def call_command(commands) = IO.popen(commands.join(" ")).close

  def compile(compiler_options: ["-O0"]) = @generator.compile
end
