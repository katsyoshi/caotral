require_relative "elf/utils"
require_relative "elf/error"
require_relative "elf/header"
require_relative "elf/program_header"
require_relative "elf/section"
require_relative "elf/section/dynamic"
require_relative "elf/section/hash"
require_relative "elf/section/rel"
require_relative "elf/section/strtab"
require_relative "elf/section/symtab"
require_relative "elf/section_header"
require_relative "elf/symtab_methods"

require_relative "elf/reader"

module Caotral
  module Binary
    class ELF
      include Enumerable
      attr_reader :sections, :program_headers
      attr_accessor :header
      def initialize
        @program_headers = []
        @sections = []
        @header = nil
      end
      def each(&block) = @sections.each(&block)
      def [](idx) = @sections[idx]
      def find_by_name(section_name) = @sections.find { |s| section_name == s.section_name }
      def select_by_name(section_name) = @sections.select { |s| section_name == s.section_name }
      def index(section_name) = @sections.index { |s| section_name == s.section_name }
      def select_by_names(section_names) = @sections.select { |section| section_names.any? { |name| name === section.section_name.to_s } }
      def without_sections(names) = @sections.reject { |s| names.any? { |name| name === s.section_name.to_s } }
      def entry_symbol
        symtab = find_by_name(".symtab")
        raise Caotral::Binary::ELF::Error, "missing .symtab section!!!" unless symtab
        raise Caotral::Binary::ELF::Error, "invalid .symtab section!!!" unless symtab.respond_to?(:find_defined_symbol)
        symtab.find_defined_symbol("_start") || symtab.find_defined_symbol("main")
      end

      def entry_start? = entry_symbol&.name_string == "_start"
    end
  end
end
