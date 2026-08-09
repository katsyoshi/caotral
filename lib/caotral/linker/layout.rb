require "caotral/binary/elf"

require_relative "error"

module Caotral
  class Linker
    class Layout
      attr_reader :debug, :shared, :executable, :pie
      LATE_SECTIONS = ["", ".shstrtab"].freeze
      PF = Caotral::Binary::ELF::ProgramHeader::PF
      LOAD_ALIGNMENT = 0x1000

      def initialize(elf:, shared:, executable:, pie:)
        @elf = elf
        @shared, @executable, @pie, @file_offset = shared, executable, pie, 0
      end

      def apply!
        classify_load_sections!
        build_program_headers!
        layout_sections!
        layout_section_headers!
        finalize_program_headers!
        finalize_elf_header!
        @elf
      end

      private
      def classify_load_sections!
        allocated_sections = @elf.sections.select { |s| s.header.allocated? }
        read_only_sections = allocated_sections.select { |s| !s.header.execinstr? && !s.header.writable? }
        executable_sections = allocated_sections.select { |s| s.header.execinstr? && !s.header.writable? }
        writable_sections = allocated_sections.select { |s| !s.header.execinstr? && s.header.writable? }
        if allocated_sections.any? { |s| s.header.execinstr? && s.header.writable? }
          raise Caotral::Linker::Error, "can not support alloc section write and executable"
        end

        @load_sections = {
          R: read_only_sections,
          RX: executable_sections,
          RW: writable_sections,
        }
      end

      def build_program_headers!
        read_only = build_program_header(type: 1, flags: PF[:R])
        executable = build_program_header(type: 1, flags: PF[:RX]) if @load_sections[:RX].any?
        writable = build_program_header(type: 1, flags: PF[:RW]) if @load_sections[:RW].any?
        lph = [read_only, executable, writable].compact

        iph = build_program_header(type: 3) if @elf.find_by_name(".interp")
        dph = build_program_header(type: 2) if @elf.find_by_name(".dynamic")
        pph = build_program_header(type: 6) if @pie
        gsph = build_program_header(type: 0x6474e551, flags: PF[:RW]) if dynamic?

        @elf.program_headers.replace([pph, *lph, iph, dph, gsph].compact)
      end

      def build_program_header(type:, flags: 0)
        ph = Caotral::Binary::ELF::ProgramHeader.new
        ph.set!(type:, flags:)
        ph
      end
      def layout_sections!
        @file_offset = header_end

        @load_sections.each do |flags, sections|
          next if sections.empty?

          @file_offset = align_up(@file_offset, LOAD_ALIGNMENT) unless flags == :R
          sections.each do |section|
            @file_offset = section.layout!(offset: @file_offset)
          end
        end

        @elf.sections.reject { |s| s.header.allocated? }.each do |section|
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
        @elf.program_headers.each do |ph|
          case ph.type
          when :PHDR
            offset, align = 64, 8
            vaddr = load_bias + offset
            paddr = vaddr
            filesz = @elf.program_headers.size * 56
            memsz = filesz
            flags = PF[:R]
          when :LOAD
            allocated_sections = @load_sections[ph.flags]

            section_end = allocated_sections.map { |s| s.header.offset + s.header.size }.max
            segment_start = ph.flags == :R ? 0 : allocated_sections.map { |s| s.header.offset }.min
            segment_end = ph.flags == :R ? [header_end, section_end].compact.max : section_end

            offset = segment_start
            vaddr = load_bias + offset
            paddr = vaddr
            filesz = segment_end - segment_start
            memsz = filesz
            flags = PF[ph.flags]
            align = LOAD_ALIGNMENT
          when :INTERP
            interp = @elf.find_by_name(".interp")
            raise Caotral::Linker::Error, "Missing .interp section" unless interp
            header = interp.header
            offset, vaddr, paddr, align = header.offset, header.addr, header.addr, 1
            filesz = interp.header.size
            memsz = filesz
            flags = PF[:R]
          when :DYNAMIC
            dynamic = @elf.find_by_name(".dynamic")
            raise Caotral::Linker::Error, "Missing .dynamic section" unless dynamic
            header = dynamic.header
            offset, vaddr, paddr, align = header.offset, header.addr, header.addr, header.addralign
            filesz = header.size
            memsz = filesz
            flags = PF[:RW]
          when :GNU_STACK
            offset, vaddr, paddr, align = 0, 0, 0, 0
            filesz, memsz, flags = 0, 0, PF[:RW]
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
      def align_up(val, align) = (val + align - 1) / align * align
      def dynamic? = @pie || @shared
      def header_end
        raise Error, "must have ELF header" unless Caotral::Binary::ELF::Header === @elf.header
        @elf.header.build.bytesize + @elf.program_headers.sum { |ph| ph.build.bytesize }
      end
    end
  end
end
