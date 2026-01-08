require "caotral/binary/elf"

require_relative "builder/text"

module Caotral
  class Assembler
    class Builder
      def initialize(instructions:) = @instructions = instructions

      def build
        elf = Caotral::Binary::ELF.new
        elf.header = Caotral::Binary::ELF::Header.new

        [
          [nil, nil],
          [".text", assemble(@instructions)],
          [".strtab", Caotral::Binary::ELF::Section::Strtab.new],
          [".symtab", Caotral::Binary::ELF::Section::Symtab.new],
          [".shstrtab", Caotral::Binary::ELF::Section::Strtab.new],
        ].each do |(section_name, body)|
          header = Caotral::Binary::ELF::SectionHeader.new
          section = Caotral::Binary::ELF::Section.new(header:, body:, section_name:)
          elf.sections << section
        end
        strtab = elf.find_by_name(".strtab")
        symtab = elf.find_by_name(".symtab")
        symtab.body = build_symtab(strtab.body)
        elf
      end

      private
      def assemble(instructions) = Caotral::Assembler::Builder::Text.new(instructions:).build
      def build_symtab(strtab)
        entries = []
        entries << Caotral::Binary::ELF::Section::Symtab.new.set!(name: 0, info: 0, shndx: 0, value: 0, size: 0)
        name = strtab.offset_of("main")
        entries << Caotral::Binary::ELF::Section::Symtab.new.set!(name:, info: 0x12, other: 0, shndx: 1, value: 0, size: 0)
        entries
      end
    end
  end
end
