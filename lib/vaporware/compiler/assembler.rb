# frozen_string_literal: true
require_relative "assembler/elf"
require_relative "assembler/elf/utils"
require_relative "assembler/elf/header"
require_relative "assembler/elf/sections"
require_relative "assembler/elf/section_header"

class Vaporware::Compiler::Assembler
  def self.assemble!(input, output = File.basename(input, ".*") + ".o") = new(input:, output:).assemble

  def initialize(input:, output: File.basename(input, ".*") + ".o", assembler: "as", type: :relocatable, debug: false)
    @input, @output = input, output
    @elf = ELF.new(type:, input:, output:, debug:)
    @assembler = assembler
    @debug = debug
  end

  def assemble(assembler: @assembler, assembler_options: [], input: @input, output: @output, debug: false)
    if ["gcc", "as"].include?(assembler)
      IO.popen([assembler, *assembler_options, "-o", output, input].join(" ")).close
    else
      to_elf(input:, output:, debug:)
    end
    output
  end
  def obj_file = @output
  def to_elf(input: @input, output: @output, debug: false) = @elf.build(input:, output:, debug:)
end
