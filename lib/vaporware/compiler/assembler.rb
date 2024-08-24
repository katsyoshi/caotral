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
    read!(input:)
    init_assemble!

    offset = 0x40
    section_headers = []
    names = []
    bodies = {
      null: nil,
      text: nil,
      data: nil,
      bss: nil,
      note: nil,
      symtab: nil,
      strtab: nil,
      shstrtab: nil,
    }
    name_idx = 0
    padding = nil
    @sections.each do |section|
      name = section.name
      names << name
      section.body.set!(name: names.join + "\0") if name == "\0.shstrtab"
      bin = section.body.build
      size = bin.bytesize
      bin << "\0" until (bin.bytesize % 8) == 0 if ["\0.text", "\0.shstrtab"].include?(name)
      bodies[section.section_name.to_sym] = bin
      header = section.header
      padding = bin.size - size if offset > 0x40 && size > 0
      if offset > 0x40 && size > 0 && padding > 0
        offset += padding
        padding = nil
      end
        
      header.set!(name: name_idx, offset:, size:) unless name == ""
      offset += size
      section_headers << header.build
      name_idx += name == "" ? 1 : name.size
    end
    w = File.open(output, "wb")
    w.write([@elf_header.build, *bodies.values, *section_headers].join)
    w.close
    [@elf_header.build, *bodies.values, *section_headers]
  end

  private
  def init_assemble! = (note!; symtab!)
  def read!(input: @input, text: @sections.text.body)
    read = { main: false }
    File.open(input, "r") do |r|
      r.each_line do |line|
        read[:main] = line.match(/main:/) unless read[:main]
        next unless read[:main] && !/main:/.match(line)
        text.assemble!(line)
      end
    end
  end
  def note! = @sections.note.body.gnu_property!
  def symtab! = @sections.symtab.body.set!(entsize: 0x18, name: 1, info: 0x10, other: 0, shndx: 1)
end
