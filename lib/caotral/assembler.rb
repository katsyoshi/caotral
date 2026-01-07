# frozen_string_literal: true
require "caotral/binary/elf"

require_relative "assembler/builder"
require_relative "assembler/reader"

class Caotral::Assembler
  GCC_ASSEMBLERS = ["gcc", "as"].freeze
  CLANG_ASSEMBLERS = ["clang", "llvm"].freeze
  ASSEMBLERS = (GCC_ASSEMBLERS + CLANG_ASSEMBLERS).freeze
  class Error < StandardError; end

  def self.assemble!(input:, output: File.basename(input, ".*") + ".o", assembler: "as", debug: false, shared:false) = new(input:, output:, assembler:, debug:).assemble

  def initialize(input:, output: File.basename(input, ".*") + ".o", assembler: "as", type: :relocatable, debug: false)
    @input, @output = input, output
    @asm_reader = Caotral::Assembler::Reader.new(input:, debug:)
    @assembler = assembler
    @debug = debug
  end

  def assemble(assembler: @assembler, assembler_options: [], input: @input, output: @output, debug: false, shared: false)
    if ASSEMBLERS.include?(assembler)
      IO.popen([command(assembler), *assembler_options, "-o", output, input].join(" ")).close
    else
      to_elf(input:, output:, debug:)
    end

    output
  end
  def obj_file = @output
  def to_elf(input: @input, output: @output, debug: false)
    elf_obj = Caotral::Assembler::Builder.new(instructions:).build
    output
  end

  def command(asm)
    case asm
    when "as", "gcc"
      gcc_assembler(asm)
    when "clang", "llvm"
      clang_assembler(asm)
    else
      raise Error, "Invalid assembler command: #{asm}"
    end
  end

  private
  def instructions = @instructions ||= @asm_reader.read
  def gcc_assembler(assembler)
    case assembler
    when "as", "gcc"
      "as"
    else
      raise Error, "Invalid assembler command: #{assembler}"
    end
  end
  
  def clang_assembler(assembler)
    case assembler
    when "clang"
      "clang"
    when "llvm"
      "clang -cc1as -triple x86_64-pc-linux-gnu -filetype obj -target-cpu x86-64 -mrelocation-model pic"
    else
      raise Error, "Invalid assembler command: #{assembler}"
    end
  end
end
