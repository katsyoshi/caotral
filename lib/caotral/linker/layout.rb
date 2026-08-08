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
      def finalize_program_headers!
        text = @elf.find_by_name(".text")
        load_bias = text.nil? ? 0 : text.header.addr - text.header.offset
        phdr = @elf.program_headers.any? { |ph| ph.type == :PHDR }
        @elf.program_headers.each do |ph|
          case ph.type
          when :PHDR
            offset, align = 64, 8
            vaddr = load_bias + offset
            paddr = vaddr
            filesz = @elf.program_headers.size * 56
            memsz = filesz
            flags = Caotral::Binary::ELF::ProgramHeader::PF[:R]
          when :LOAD
            text = @elf.find_by_name(".text")
            next unless text

            allocated_sections = @elf.sections.select { |s| s.header.allocated? }
            segment_start = phdr ? 0 : allocated_sections.map { |s| s.header.offset }.min
            segment_end = allocated_sections.map { |s| s.header.offset + s.header.size }.max

            next unless segment_end

            offset = segment_start
            vaddr = load_bias + offset
            paddr = vaddr
            filesz = segment_end - segment_start
            memsz = filesz
            flags = Caotral::Binary::ELF::ProgramHeader::PF[:RWX]
            align = 0x1000
          when :INTERP
            interp = @elf.find_by_name(".interp")
            raise Caotral::Linker::Error, "Missing .interp section" unless interp
            header = interp.header
            offset, vaddr, paddr, align = header.offset, header.addr, header.addr, 1
            filesz = interp.header.size
            memsz = filesz
            flags = Caotral::Binary::ELF::ProgramHeader::PF[:R]
          when :DYNAMIC
            dynamic = @elf.find_by_name(".dynamic")
            raise Caotral::Linker::Error, "Missing .dynamic section" unless dynamic
            header = dynamic.header
            offset, vaddr, paddr, align = header.offset, header.addr, header.addr, header.addralign
            filesz = header.size
            memsz = filesz
            flags = Caotral::Binary::ELF::ProgramHeader::PF[:RW]
          when :GNU_STACK
            offset, vaddr, paddr, align = 0, 0, 0, 0
            filesz = 0
            memsz = 0
            flags = Caotral::Binary::ELF::ProgramHeader::PF[:RW]
          else
            raise Caotral::Linker::Error, "Not Implemented: #{ph.type} program header layout"
          end
          ph.set!(offset:, vaddr:, paddr:, filesz:, memsz:, flags:, align:)
        end
      end
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
