require_relative "elf/utils"
require_relative "elf/error"

module Caotral
  class Binary
    class ELF
      include Enumerable
      attr_reader :sections, :header
      def initialize
        @sections = []
        @header = nil
      end
      def each(&block) = @sections.each(&block)
      def [](idx) = @sections[idx]
      def select_by_name(section_name) = @sections.select { [it.section_name, it.name].include?(section_name.to_s) }
    end
  end
end
