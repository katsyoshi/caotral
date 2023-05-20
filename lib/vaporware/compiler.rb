# frozen_string_literal: true

require_relative "compiler/generator"

module Vaporware
  # Your code goes here...
  class Compiler
    def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
      _precompile = "#{dest}.s"
      s = new(source, _precompile: _precompile, debug:, shared:)
      s.compile(compiler:, compiler_options:)
    end

    def initialize(source, _precompile: "tmp.s", debug: false, shared: false)
      @generator = Vaporware::Compiler::Generator.new(source, precompile: _precompile, debug:, shared:)
    end

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
        @generator.build(@generator.ast, output)
        # epilogue
        @generator.epilogue(output)
      else
        @generator.prologue_methods(output)
        output.puts ".globl main" unless @generator.shared
        @generator.build(@generator.ast, output)
        # epilogue
        @generator.epilogue(output)
      end
      output.close
      compiler_options += @generator.compile_shared_option if @generator.shared
      @generator.call_compiler(compiler:, compiler_options:)
    end
  end
end
