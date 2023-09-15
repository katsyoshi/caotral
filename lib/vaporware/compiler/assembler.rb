# frozen_string_literal: true
require_relative "assembler/elf"
require_relative "assembler/elf/header"
require_relative "assembler/elf/section"
require_relative "assembler/elf/section/text"
require_relative "assembler/elf/section/bss"
require_relative "assembler/elf/section/data"
require_relative "assembler/elf/section/note"
require_relative "assembler/elf/section/symtab"
require_relative "assembler/elf/section/strtab"
require_relative "assembler/elf/section/shsymtab"
require_relative "assembler/elf/section/shstrtab"
require_relative "assembler/elf/section_header"

class Vaporware::Compiler::Assembler
  def self.assemble!(input, output = File.basename(input, ".*") + ".o") = new(input:, output:).assemble

  def initialize(input:, output: File.basename(input, ".*") + ".o", assembler: "as", type: :relocator, debug: false)
    @input, @output = input, output
    @elf_header = ELF::Header.new(type:)
    @sections = {
      null: { body: nil, header: ELF::SectionHeader.new.null! },
      text: { body: ELF::Section::Text.new, header: ELF::SectionHeader.new.text! },
      data: { body: ELF::Section::Data.new, header: ELF::SectionHeader.new.data! },
      bss: { body: ELF::Section::BSS.new, header: ELF::SectionHeader.new.bss! },
      note: { body: ELF::Section::Note.new.gnu_property!, header: ELF::SectionHeader.new.note! },
      symtab: { body: ELF::Section::Symtab.new, header: ELF::SectionHeader.new.symtab! },
      strtab: { body: ELF::Section::Strtab.new, header: ELF::SectionHeader.new.strtab! },
      shsymtab: { body: ELF::Section::Shsymtab.new, header: ELF::SectionHeader.new.shsymtab! },
    }
    @debug = debug
  end

  def assemble(assembler: "as", assembler_options: [], input: @input, output: @output, debug: false)
    if ["gcc", "as"].include?(assembler)
      IO.popen([assembler, *assembler_options, "-o", output, input].join(" ")).close
    else
      to_elf(input:, output:)
    end
    output
  end
  def obj_file = @output

  private
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
