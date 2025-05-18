# frozen_string_literal: true

require_relative "vaporware/version"

require_relative "vaporware/assembler"
require_relative "vaporware/compiler"
require_relative "vaporware/linker"

module Vaporware
  module_function
  def compile!(input:, assembler: "as", linker: "ld", output: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
    d = File.expand_path(output)
    basename = "#{File.dirname(d)}/#{File.basename(d, ".*")}"
    execf = "#{basename}#{File.extname(d)}"
    compiler = Vaporware::Compiler.compile!(input:, output: basename + ".s", debug:, compiler_options:, shared:)
    assembler = Vaporware::Assembler.assemble!(input: basename+".s", output: basename+".o", assembler:, debug:)
    linker = Vaporware::Linker.link!(input: basename+".o", output: execf, linker:, debug:, shared:)
  end
end
