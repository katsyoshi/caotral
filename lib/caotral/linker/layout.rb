require "caotral/binary/elf"

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
      def build_program_headers!
        lph = build_program_header(type: 1)
        iph = build_program_header(type: 3) if @elf.find_by_name(".interp")
        dph = build_program_header(type: 2) if @elf.find_by_name(".dynamic")
        pph = build_program_header(type: 6) if @pie
        if @pie || @shared
          gsph = build_program_header(
            type: 0x6474e551,
            flags: Caotral::Binary::ELF::ProgramHeader::PF[:RW]
          )
        end

        @elf.program_headers.replace([pph, lph, iph, dph, gsph].compact)
      end

      def build_program_header(type:, flags: 0)
        ph = Caotral::Binary::ELF::ProgramHeader.new
        ph.set!(type:, flags:)
        ph
      end
      def layout_sections! = nil
      def layout_section_headers! = nil
      def finalize_program_headers! = nil
      def finalize_elf_header! = nil
    end
  end
end
