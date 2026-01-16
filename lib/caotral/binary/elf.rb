require_relative "elf/utils"
require_relative "elf/error"
require_relative "elf/header"
require_relative "elf/program_header"
require_relative "elf/section"
require_relative "elf/section/rel"
require_relative "elf/section/strtab"
require_relative "elf/section/symtab"
require_relative "elf/section_header"
require_relative "elf/reader"

module Caotral
  module Binary
    class ELF
      include Enumerable
      attr_reader :sections
      attr_accessor :header
      def initialize
        @sections = []
        @header = nil
      end
      def each(&block) = @sections.each(&block)
      def [](idx) = @sections[idx]
      def find_by_name(section_name) = @sections.find { |s| section_name == s.section_name }
      def select_by_name(section_name) = @sections.select { |s| section_name == s.section_name }
      def index(section_name) = @sections.index { |s| section_name == s.section_name }
      def select_by_names(section_names) = @sections.select { |section| section_names.any? { |name| name === section.section_name.to_s } }
      def without_sections(names) = @sections.reject { |s| names.any? { |name| s.section_name == name } }
    end
  end
end
