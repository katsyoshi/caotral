require_relative "elf/program_header"

module Caotral
  class Linker
    class Writer
      include Caotral::Assembler::ELF::Utils
      ALLOW_SECTIONS = %w(.text .strtab .shstrtab).freeze
      R_X86_64_PC32 = 2
      R_X86_64_PLT32 = 4
      ALLOW_RELOCATION_TYPES = [R_X86_64_PC32, R_X86_64_PLT32].freeze
      RELOCATION_SECTION_NAMES = [".rela.text", ".rel.text"].freeze
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
        rel_sections = @elf_obj.sections.select { RELOCATION_SECTION_NAMES.include?(it.section_name) }
        start_bytes = [0xe8, *[0] * 4, 0x48, 0x89, 0xc7, 0x48, 0xc7, 0xc0, 0x3c, 0x00, 0x00, 0x00, 0x0f, 0x05]
        symtab = @elf_obj.sections[".symtab"]
        symtab_body = symtab.body
        old_text = text_section.body
        main_sym = symtab_body.find { |sym| sym.name_string == "main" }
        text_offset = 0x1000
        base_addr = 0x400000
        align = 0x1000
        vaddr = base_addr + text_offset
        paddr = base_addr + text_offset
        start_len = start_bytes.length
        start_addr = base_addr + text_offset
        main_offset = main_sym.value + start_len
        start_bytes[1, 4] = num2bytes((main_offset - 5), 4)
        start_bytestring = start_bytes.pack("C*")
        text_section.body = start_bytestring + old_text
        type, flags = 1, 5
        filesz = text_section.body.bytesize
        memsz = filesz

        rel_sections.each do |rel|
          target = @elf_obj.sections[rel.header.info]
          bytes = target.body.dup
          rel.body.each do |entry|
            next unless ALLOW_RELOCATION_TYPES.include?(entry.type)
            a = entry.type == R_X86_64_PC32 ? 4 : 0
            sym = symtab_body[entry.sym]
            target_addr = target == text_section ? vaddr : target.header.addr
            sym_addr = sym.value + target_addr + (target == text_section ? start_len : 0)
            sym_offset = entry.offset + (target == text_section ? start_len : 0)
            sym_addend = entry.addend? ? entry.addend : bytes[sym_offset, 4].unpack1("l<")
            value = sym_addr + sym_addend - (target_addr + sym_offset + a)
            bytes[sym_offset, 4] = [value].pack("l<")
          end
          target.body = bytes
        end
        header.set!(entry: @entry || base_addr + text_offset)
        ph.set!(type:, offset: text_offset, vaddr:, paddr:, filesz:, memsz:, flags:, align:)
        text_section.header.set!(size: text_section.body.bytesize, addr: vaddr, offset: text_offset)
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
          lookup_name = section.name.sub(/\A\0/, "")
          name_offset = names.offset_of(lookup_name)
          section.header.set!(name: name_offset) if name_offset
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
