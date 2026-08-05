require "caotral/binary/elf"

require_relative "error"

module Caotral
  class Linker
    class Layout
      attr_reader :debug, :shared, :executable, :pie
      LATE_SECTIONS = ["", ".shstrtab"].freeze

      def initialize(elf:, shared:, executable:, pie:)
        @elf = elf
        @shared, @executable, @pie, @file_offset = shared, executable, pie, 0
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
      def layout_sections!
        header_end = (64 + (@elf.program_headers.size * 56))
        first_section = @elf.sections.find { |s| s.section_name && !LATE_SECTIONS.include?(s.section_name) }
        first_offset = first_section&.header&.offset.to_i || 0
        @file_offset = [header_end, first_offset].max

        @elf.sections.each do |section|
          next if section.section_name.nil?
          next if LATE_SECTIONS.include?(section.section_name)
          @file_offset = section.layout!(offset: @file_offset)
        end

        text = @elf.find_by_name(".text")
        return unless text
        @elf.sections.each do |section|
          next unless section.header.allocated?

          addr = text.header.addr + (section.header.offset - text.header.offset)
          section.header.set!(addr:)
        end
      end
      def layout_section_headers!
        shstrtab = @elf.find_by_name(".shstrtab")
        raise Caotral::Linker::Error, "Missing .shstrtab section" unless shstrtab
        section_names = @elf.sections.map(&:section_name).map(&:to_s)
        unless section_names.last == ".shstrtab"
          raise Caotral::Linker::Error, "section header string table must be the last section"
        end

        shstrtab.body.names = section_names.uniq.join("\0") + "\0"
        @file_offset = shstrtab.layout!(offset: @file_offset)

        @section_headers_offset = @file_offset
        @file_offset += @elf.sections.sum { |section| section.header.build.bytesize }
      end
      def finalize_program_headers! = nil
      def finalize_elf_header!
        header = @elf.header
        raise Caotral::Linker::Error, "Missing ELF header" unless header

        type_sym = dynamic? ? :DYN : :EXEC
        type = Caotral::Binary::ELF::Header::TYPE[type_sym]
        phoffset, ehsize, phsize = 64, 64, 56

        header.set!(
          type:, phoffset:, ehsize:, phsize:,
          phnum: @elf.program_headers.size,
          shnum: @elf.sections.size,
          shstrndx: @elf.index(".shstrtab"),
          shoffset: @section_headers_offset
        )
      end
      def dynamic? = @pie || @shared
    end
  end
end
