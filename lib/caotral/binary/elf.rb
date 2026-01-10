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
      def find_by_name(section_name) = @sections.find { section_name == it.section_name }
      def select_by_name(section_name) = @sections.select { section_name == it.section_name }
      def index(section_name) = @sections.index { section_name == it.section_name }
    end
  end
end
