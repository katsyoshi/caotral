# frozen_string_literal: true

require_relative "compiler/generator"
require_relative "compiler/assembler"

class Vaporware::Compiler
  def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
    _precompile = "#{dest}.s"
    s = new(source, _precompile: _precompile, debug:, shared:)
    s.compile(compiler:, compiler_options:)
    obj_file = s.assemble(input: _precompile, assembler: "as", debug:)
    s.link(obj_file)
  end

  def initialize(source, _precompile: "tmp.s", debug: false, shared: false)
    @generator = Vaporware::Compiler::Generator.new(source, precompile: _precompile, debug:, shared:)
    @assembler = Vaporware::Compiler::Assembler.new(@generator.precompile, debug:)
  end

  def assemble(input:, output: File.basename(input, ".*") + ".o", assembler: "gcc", assembler_options: [], debug: false)
    if ["gcc", "as"].include?(assembler)
      assemble_commands = [assembler, *assembler_options, "-o", output, input].compact
      call_commands(assemble_commands)
    else
      @assembler.assemble(input, output)
    end
    output
  end

  def link(input, output = File.basename(input, ".*"), linker: "mold", linker_options: ["-m", "elf_x86_64", "-dynamic-linker", "/lib64/ld-linux-x86-64.so.2", "/lib64/libc.so.6", "/usr/lib64/crt1.o", input])
    linker_commands = [linker, *linker_options, "-o", output].compact
    call_commands(linker_commands)
  end

  def call_commands(commands) = IO.popen(commands).close

  def compile(compiler: "gcc", compiler_options: ["-O0"])
    @generator.register_var_and_method(@generator.ast)

    output = File.open(@generator.precompile, "w")
    # prologue
    output.puts ".intel_syntax noprefix"
    if @generator.defined_methods.empty?
      @generator.main = true
      output.puts ".globl main"
      output.puts "main:"
      output.puts "  push rbp"
      output.puts "  mov rbp, rsp"
      output.puts "  sub rsp, #{@generator.defined_variables.size * 8}"
      @generator.to_asm(@generator.ast, output)
      # epilogue
      @generator.epilogue(output)
    else
      @generator.prologue_methods(output)
      output.puts ".globl main" unless @generator.shared
      @generator.to_asm(@generator.ast, output)
      # epilogue
      @generator.epilogue(output)
    end
    output.close
    compiler_options += @generator.compile_shared_option if @generator.shared
  end
end
