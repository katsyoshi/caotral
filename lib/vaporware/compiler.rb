# frozen_string_literal: true

require_relative "compiler/generator"
require_relative "compiler/assembler"
require_relative "compiler/linker"

class Vaporware::Compiler
  def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
    s = new(input: source, output: dest, debug:, shared:)
    s.compile(compiler_options:)
    s.assemble(input: dest.to_s + ".s", assembler: "as", debug:)
    s.link
  end

  def initialize(input:, output: File.basename(input, ".*"), linker: "ld", assembler: "as", debug: false, shared: false)
    @generator = Vaporware::Compiler::Generator.new(input:, output: output + ".s", debug:, shared:)
    @assembler = Vaporware::Compiler::Assembler.new(input: @generator.precompile, output: output + ".o", assembler:, debug:)
    output = "lib#{output}.so" if shared && output !~ /^lib.+\.so$/
    @linker = Vaporware::Compiler::Linker.new(input: @assembler.obj_file, output:, linker:, debug:, shared:)
  end

  def assemble(input:, output: File.basename(input, ".*") + ".o", assembler: "as", assembler_options: [], debug: false) = @assembler.assemble(input:, output:, assembler:, assembler_options:, debug:)
  def link = @linker.link
  def compile(compiler_options: ["-O0"]) = @generator.compile
end
