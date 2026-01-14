require "set"
require "caotral/binary/elf"

module Caotral
  class Linker
    class Builder
      SYMTAB_BIND = { locals: 0, globals: 1, weaks: 2, }.freeze
      BIND_BY_VALUE = SYMTAB_BIND.invert.freeze
      attr_reader :symbols

      def initialize(elf_objs:)
        @elf_objs = elf_objs
        @symbols = { locals: Set.new, globals: Set.new, weaks: Set.new }
      end

      def build
        raise Caotral::Binary::ELF::Error, "no ELF objects to link" if @elf_objs.empty?
        elf = Caotral::Binary::ELF.new
        elf_obj = @elf_objs.first
        first_text = elf_obj.find_by_name(".text")
        text_section = Caotral::Binary::ELF::Section.new(
          body: String.new,
          section_name: ".text",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        strtab_section = Caotral::Binary::ELF::Section.new(
          body: Caotral::Binary::ELF::Section::Strtab.new("\0".b),
          section_name: ".strtab",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        elf.header = elf_obj.header.dup
        strtab_names = Set.new
        @elf_objs.each do |elf_obj|
          text = elf_obj.find_by_name(".text")
          text_section.body << text.body unless text.nil?
          strtab = elf_obj.find_by_name(".strtab")
          unless strtab.nil?
            strtab.body.names.split("\0").each { |name| strtab_names << name }
          end
        end
        strtab_section.body.names = strtab_names.to_a.sort.join("\0") + "\0"
        elf.sections << text_section
        elf.sections << strtab_section
        @elf_objs.first.without_section(".text").each do |section|
          elf.sections << section
        end
        elf
      end
      def resolve_symbols
        @elf_objs.each do |elf_obj|
          elf_obj.find_by_name(".symtab").body.each do |symtab|
            name = symtab.name_string
            next if name.empty?
            info = symtab.info
            bind = BIND_BY_VALUE.fetch(info >> 4)
            if bind == :globals && @symbols[bind].include?(name)
              raise Caotral::Binary::ELF::Error,"cannot add into globals: #{name}"
            end
            @symbols[bind] << name
          end
        end
        @symbols
      end
    end
  end
end
