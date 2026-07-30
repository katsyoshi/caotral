module Caotral
  class Linker
    class Layout
      attr_reader :debug, :shared, :executable, :pie

      def initialize(elf:, shared:, executable:, pie:)
        @elf = elf
        @shared = shared
        @executable = executable
        @pie = pie
      end

      def apply!
        build_program_headers!
        layout_sections!
        layout_section_headers!
        finalize_program_headers!
        finalize_elf_header!
        @elf
      end

      private
      def build_program_headers! = @elf.build_program_headers!
      def layout_sections! = @elf.layout_sections!
      def layout_section_headers! = @elf.layout_section_headers!
      def finalize_program_headers! = @elf.finalize_program_headers!
      def finalize_elf_header = @elf.finalize_heder!
    end
  end
end
