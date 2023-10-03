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
    @sections = ELF::Sections.new
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
    program_size = 0
    read(input:)
    elf_header = @elf_header.build

    offset = 0
    section_headers = []
    name = []
    bins = []
    @sections.each do |section|
      name << section.name
      bin = section.body.build
      size = bin.bytesize
      offset += size
      section.body.align(bin, 8)
      bins << bin
      header = section.header
      header.set!(offset:)
      section_headers << header.build
    end
    f = File.open(output, "wb")
  ensure
    f.close
    f.path
  end

  def read(input: @input, text: @sections.text.body)
    read = { main: false }
    File.open(input, "r") do |r|
      r.each_line do |line|
        read[:main] = /main:/.match(line) unless read[:main]
        next unless read[:main] && !/main:/.match(line)
        text.assemble!(line)
      end
    end
  end
end
