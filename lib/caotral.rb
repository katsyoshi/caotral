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
    compile(input:, output: basename+".s", debug:, shared:)
    assemble(input: basename+".s", output: basename+".o", assembler:, debug:, shared:)
    link(input: basename+".o", output: execf, linker:, debug:, shared:)
  end
  def compile(input:, output: "tmp.s", debug: false, shared: false)
    Vaporware::Compiler.compile!(input:, output:, debug:)
  end
  def assemble(input:, output: "tmp.o", debug: false, shared: false, assembler: "as")
    Vaporware::Assembler.assemble!(input:, output:, debug:, assembler:, shared:)
  end
  def link(input:, output: "tmp", linker: "ld", debug: false, shared: false)
    Vaporware::Linker.link!(input:, output:, linker:, debug:, shared:)
  end
end
