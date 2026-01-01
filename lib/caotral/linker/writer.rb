require_relative "elf/program_header"
module Caotral
  class Linker
    class Writer
      ALLOW_SECTIONS = %w(.text .strtab .shstrtab).freeze
      attr_reader :elf_obj, :output, :entry, :debug
      def self.write!(elf_obj:, output:, entry: nil, debug: false)
        new(elf_obj:, output:, entry:, debug:).write
      end
      def initialize(elf_obj:, output:, entry: nil, debug: false)
        @elf_obj, @output, @entry, @debug = elf_obj, output, entry, debug
      end
      def write
        f = File.open(@output, "wb")
        phoffset, phnum, phsize, ehsize = 64, 1, 56, 64
        header = @elf_obj.header.set!(type: 2, phoffset:, phnum:, phsize:, ehsize:)
        ph = Caotral::Linker::ELF::ProgramHeader.new
        text_section = @elf_obj.sections[".text"]
        filesz = text_section.header.size
        memsz = filesz
        offset = text_offset = 0x1000
        base_addr = 0x400000
        align = 0x1000
        vaddr = base_addr + text_offset
        paddr = base_addr + text_offset
        type, flags = 1, 5
        header.set!(entry: @entry || base_addr + text_offset)
        ph.set!(type:, offset:, vaddr:, paddr:, filesz:, memsz:, flags:, align:)
        f.write(@elf_obj.header.build)
        f.write(ph.build)
        gap = [text_offset - f.pos, 0].max
        f.write("\0" * gap)
        f.write(text_section.body)
        shstrtab = @elf_obj.sections[".shstrtab"]
        shstrtab_offset = f.pos
        f.write(shstrtab.body.names)
        shstrtab.header.set!(offset: shstrtab_offset, size: shstrtab.body.names.bytesize)
        write_sections = @elf_obj.sections.select { ALLOW_SECTIONS.include?(it.section_name) || it.name == "" }
        shoffset = f.pos
        shstrndx = write_sections.index { it.section_name == ".shstrtab" }
        shnum = write_sections.size
        @elf_obj.header.set!(shoffset:, shnum:, shstrndx:)
        names = @elf_obj.sections[".shstrtab"].body

        write_sections.each do |section|
          section_name = section.section_name == "null" ? "" : section.section_name
          name_offset = names.offset_of(section_name)
          raise "Section name #{section_name} not found in .shstrtab" unless name_offset
          section.header.set!(name: name_offset)
          f.write(section.header.build)
        end
        f.seek(0)
        f.write(@elf_obj.header.build)
        output
      ensure
        f.close if f
      end
    end
  end
end
