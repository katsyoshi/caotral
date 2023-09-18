# frozen_string_literal: true
require_relative "assembler/elf"
require_relative "assembler/elf/header"
require_relative "assembler/elf/sections"
require_relative "assembler/elf/section_header"

class Vaporware::Compiler::Assembler
  def self.assemble!(input, output = File.basename(input, ".*") + ".o") = new(input:, output:).assemble

  def initialize(input:, output: File.basename(input, ".*") + ".o", assembler: "as", type: :relocator, debug: false)
    @input, @output = input, output
    @elf_header = ELF::Header.new(type:)
    @assembler = assembler
    @sections = Vaporware::Compiler::Assembler::ELF::Sections.new
    @debug = debug
  end

  def assemble(assembler: @assembler, assembler_options: [], input: @input, output: @output, debug: false)
    if ["gcc", "as"].include?(assembler)
      IO.popen([assembler, *assembler_options, "-o", output, input].join(" ")).close
    else
      to_elf(input:, output:)
    end
    output
  end
  def obj_file = @output

  def to_elf(input: @input, output: @output, debug: false)
    f = File.open(output, "wb")
    read = { main: false }
    program_size = 0
    text = @sections[:text][:body]
    File.open(input, "r") do |r|
      r.each_line do |line|
        read[:main] = /main:/.match(line) unless read[:main]
        next unless read[:main] && !/main:/.match(line)
        text.assemble!(line)
      end
    end
    f.write(@elf_header.build)
    bins = []
    section_headers = []
    @sections.values.map do |section|
      bins << section[:body].build
      section_headers << section[:header].build
    end

    f.close
    f.path
  end
end
