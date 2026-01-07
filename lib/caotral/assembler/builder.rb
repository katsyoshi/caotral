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
        elf
      end

      private def assemble(instructions)
        Caotral::Assembler::Builder::Text.new(instructions:).build
      end
    end
  end
end
