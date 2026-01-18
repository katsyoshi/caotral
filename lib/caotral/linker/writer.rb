require "caotral/binary/elf"

module Caotral
  class Linker
    class Writer
      include Caotral::Binary::ELF::Utils
      R_X86_64_PC32 = 2
      R_X86_64_PLT32 = 4
      ALLOW_RELOCATION_TYPES = [R_X86_64_PC32, R_X86_64_PLT32].freeze
      RELOCATION_SECTION_NAMES = [".rela.text", ".rel.text"].freeze
      attr_reader :elf_obj, :output, :entry, :debug
      def self.write!(elf_obj:, output:, entry: nil, debug: false, executable: true, shared: false)
        new(elf_obj:, output:, entry:, debug:, shared:, executable:).write
      end
      def initialize(elf_obj:, output:, entry: nil, debug: false, executable: true, shared: false)
        @elf_obj, @output, @entry, @debug, @executable, @shared = elf_obj, output, entry, debug, executable, shared
        @write_sections = write_order_sections
      end
      def write
        f = File.open(@output, "wb")
        phoffset, phnum, phsize, ehsize = 64, 1, 56, 64
        header = @elf_obj.header.set!(type: 2, phoffset:, phnum:, phsize:, ehsize:)
        ph = Caotral::Binary::ELF::ProgramHeader.new
        text_offset = text_section.header.offset
        align = 0x1000
        vaddr = text_section.header.addr
        paddr = vaddr
        type, flags = 1, 5
        filesz = text_section.body.bytesize
        memsz = filesz

        header.set!(entry: @entry || vaddr)
        ph.set!(type:, offset: text_offset, vaddr:, paddr:, filesz:, memsz:, flags:, align:)
        f.write(@elf_obj.header.build)
        f.write(ph.build)
        gap = [text_offset - f.pos, 0].max
        f.write("\0" * gap)
        f.write(text_section.body)
        symtab_offset = f.pos
        symtab_section.body.each { |sym| f.write(sym.build) }
        symtab_entsize = symtab_section.body.first&.build&.bytesize.to_i
        symtab_size = f.pos - symtab_offset
        symtab_section.header.set!(offset: symtab_offset, size: symtab_size, entsize: symtab_entsize)
        strtab_offset = f.pos
        f.write(strtab_section.body.build)
        strtab_section.header.set!(offset: strtab_offset, size: strtab_section.body.names.bytesize)

        rel_sections.each do |rel|
          rel_offset = f.pos
          rel.body.each { |entry| f.write(entry.build) }
          rel_size = f.pos - rel_offset
          entsize = rel.body.first&.build&.bytesize.to_i
          rel.header.set!(offset: rel_offset, size: rel_size, entsize:)
        end
        offset = f.pos
        names = @write_sections.map { |s| s.section_name.to_s }
        if names.last != ".shstrtab"
          raise Caotral::Binary::ELF::Error, "section header string table must be the last section"
        end
        shstrtab_section.body.names = names.uniq.join("\0") + "\0"
        shstrtab_section.header.set!(offset:, size: shstrtab_section.body.names.bytesize)
        f.write(shstrtab_section.body.names)
        shoffset = f.pos
        shstrndx  = write_section_index(".shstrtab")
        strtabndx = write_section_index(".strtab")
        symtabndx = write_section_index(".symtab")
        shnum = @write_sections.size
        @elf_obj.header.set!(shoffset:, shnum:, shstrndx:)
        names = shstrtab_section.body

        @write_sections.each do |section|
          header = section.header
          lookup_name = section.section_name
          name_offset = names.offset_of(lookup_name)
          name, info, entsize = (name_offset.nil? ? 0 : name_offset), header.info, header.entsize
          link = header.link
          link = strtabndx if section.section_name == ".symtab"
          if [:rel, :rela].include?(header.type)
            link = symtabndx
            info = ref_index(section.section_name)
          end
          header.set!(name:, info:, link:, entsize:)
          f.write(section.header.build)
        end

        f.seek(0)
        f.write(@elf_obj.header.build)
        output
      ensure
        f.close if f
      end

      private
      def write_order_sections
        write_order = []
        write_order << @elf_obj.sections.find { |s| s.section_name.nil? }
        write_order << @elf_obj.find_by_name(".text")
        write_order << @elf_obj.find_by_name(".symtab")
        write_order << @elf_obj.find_by_name(".strtab")
        write_order.concat(@elf_obj.select_by_names(RELOCATION_SECTION_NAMES))
        write_order << @elf_obj.find_by_name(".shstrtab")
        write_order.compact
      end
      def write_section_index(section_name) = @write_sections.index { it.section_name == section_name }
      def ref_index(section_name)
        ref_name = section_name.split(".").filter { |sn| !sn.empty? && sn != "rel" && sn != "rela" }
        ref_name = "." + ref_name.join(".")
        ref = @write_sections.find { |s| s.section_name == ref_name }
        raise Caotral::Binary::ELF::Error, "cannot find reference section for #{section_name}" if ref.nil?
        write_section_index(ref.section_name)
      end

      def text_section = @text_section ||= @write_sections.find { |s| ".text" === s.section_name.to_s }
      def rel_sections = @rel_sections ||= @write_sections.select { RELOCATION_SECTION_NAMES.include?(it.section_name) }
      def symtab_section = @symtab_section ||= @write_sections.find { |s| ".symtab" === s.section_name.to_s }
      def strtab_section = @strtab_section ||= @write_sections.find { |s| ".strtab" === s.section_name.to_s }
      def shstrtab_section = @shstrtab_section ||= @write_sections.find { |s| ".shstrtab" === s.section_name.to_s }
    end
  end
end
