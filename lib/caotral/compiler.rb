# frozen_string_literal: true

require_relative "compiler/generator"

class Vaporware::Compiler
  attr_reader *%i(generator assembler linker)

  def self.compile!(input:, output: "tmp.s", debug: false, compiler_options: ["-O0"], shared: false)
    compiler = new(input:, output:, debug:, shared:,)
    compiler.compile(compiler_options:)
  end

  def initialize(input:, output:, debug: false, shared: false)
    @generator = Vaporware::Compiler::Generator.new(input:, output:, debug:, shared:)
  end
  def compile(compiler_options: ["-O0"]) = @generator.compile
end
