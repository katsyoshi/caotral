# frozen_string_literal: true

require_relative "compiler/generator"
require_relative "compiler/assembler"
require_relative "compiler/linker"

class Vaporware::Compiler
  attr_reader *%i(generator assembler linker)

  def self.compile(source, assembler: "as", linker: "ld", dest: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
    compiler = new(input: source, output: dest, debug:, shared:, linker:, assembler:)
    compiler.compile(compiler_options:)
    compiler.assemble(input: dest.to_s + ".s", assembler:, debug:)
    compiler.link
  end

  def initialize(input:, output: File.basename(input, ".*"), linker: "ld", assembler: "as", debug: false, shared: false)
    @generator = Vaporware::Compiler::Generator.new(input:, output: output + ".s", debug:, shared:)
    @assembler = Vaporware::Compiler::Assembler.new(input: @generator.precompile, output: output + ".o", assembler:, debug:)
    @linker = Vaporware::Compiler::Linker.new(input: @assembler.obj_file, output:, linker:, debug:, shared:)
  end

  def assemble(input:, output: File.basename(input, ".*") + ".o", assembler: "as", assembler_options: [], debug: false) = @assembler.assemble(input:, output:, assembler:, assembler_options:, debug:)
  def link = @linker.link
  def compile(compiler_options: ["-O0"]) = @generator.compile
end
