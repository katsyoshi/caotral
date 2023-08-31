# frozen_string_literal: true

require_relative "compiler/generator"

module Vaporware
  # Your code goes here...
  class Compiler
    def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
      _precompile = "#{dest}.s"
      s = new(source, _precompile: _precompile, debug:, shared:)
      s.compile(compiler:, compiler_options:)
      obj = s.assemble(input: _precompile, compmiler:, compiler_options:, debug:)
      s.link(input: obj,link_options:)
    end

    def initialize(source, _precompile: "tmp.s", debug: false, shared: false)
      @generator = Vaporware::Compiler::Generator.new(source, precompile: _precompile, debug:, shared:)
    end

    def assemble(input: precompile, output: File.basename(precompile, ".*") + ".o", compiler: "gcc", compiler_options: ["-O0"], debug: false)
      base_name = File.basename(input, ".*")
      name = shared ? "lib#{base_name}.so" : base_name
      if compiler == "gcc"
        compile_commands = [compiler, *compiler_options, "-o", name, input].compact
        call_compiler(compile_commands)
      else
        Vaporware::Compiler::Assembler.assemble!(input, name)
      end

      File.delete(input) unless debug
      nil
    end

    def call_compiler(compile_commands) = IO.popen(compile_commands).close

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
      @generator.to_elf(input: @generator.precompile, compiler:, compiler_options:, debug: @generator.debug)
    end
  end
end
