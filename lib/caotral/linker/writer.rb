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
      def initialize(elf_obj:, output:, entry: nil, debug: false, executable: true, shared: false, pie: false)
        @elf_obj, @output, @entry, @debug, @executable, @shared, @pie = elf_obj, output, entry, debug, executable, shared, pie
        @write_sections = write_order_sections
      end

      def write
        f = File.open(@output, "wb")
        phoffset, phsize, ehsize = 64, 56, 64
        e_type = elf_type

        # PT_LOAD
        lph = Caotral::Binary::ELF::ProgramHeader.new
        # PT_INTERP
        iph = Caotral::Binary::ELF::ProgramHeader.new if interp_section
        # PT_DYNAMIC
        dph = Caotral::Binary::ELF::ProgramHeader.new if dynamic_section
        phnum = [lph, iph, dph].compact.size
        header = @elf_obj.header.set!(type: e_type, phoffset:, phnum:, phsize:, ehsize:)
        text_offset = text_section.header.offset
        align = 0x1000
        vaddr = text_section.header.addr
        paddr = vaddr
        type, flags = 1, program_header_flags(:RX)
        filesz = text_section.body.bytesize
        memsz = filesz
        entry = @shared ? 0 : (@entry || vaddr)

        header.set!(entry:)
        lph.set!(type:, offset: text_offset, vaddr:, paddr:, filesz:, memsz:, flags:, align:)
        f.write(@elf_obj.header.build)
        f.write(lph.build)
        f.write(iph.build) if iph
        gap = [text_offset - f.pos, 0].max
        f.write("\0" * gap)
        f.write(text_section.body)
        write_shared_dynamic_sections(file: f) if @shared || @pie
        ph_pos = phoffset
        if iph
          ish = interp_section.header
          iph.set!(type: 3, offset: ish.offset, vaddr: 0, paddr: 0, filesz: ish.size, memsz: ish.size, flags: program_header_flags(:R), align: 1)
          cur = f.pos
          f.seek(ph_pos += phsize)
          f.write(iph.build)
          f.seek(cur)
        end
        if dph
          dsh = dynamic_section.header
          dph.set!(type: 2, offset: dsh.offset, filesz: dsh.size, memsz: dsh.size, vaddr: dsh.addr || 0, paddr: dsh.addr || 0, flags: program_header_flags(:R), align: dsh.addralign)
          cur = f.pos
          f.seek(ph_pos += phsize)
          f.write(dph.build)
          f.seek(cur)
        end
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
        symtabndx = write_section_index(".symtab")
        shnum = @write_sections.size
        @elf_obj.header.set!(shoffset:, shnum:, shstrndx:)
        names = shstrtab_section.body

        @write_sections.each do |section|
          header = section.header
          lookup_name = section.section_name
          name_offset = names.offset_of(lookup_name)
          name, info, entsize = (name_offset.nil? ? 0 : name_offset), header.info, header.entsize
          link = link_index(section.section_name)
          link = header.link if link.nil?
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
        write_order << @elf_obj.find_by_name(".interp")
        write_order << @elf_obj.find_by_name(".dynstr")
        write_order << @elf_obj.find_by_name(".dynsym")
        write_order << @elf_obj.find_by_name(".dynamic")
        write_order << @elf_obj.find_by_name(".symtab")
        write_order << @elf_obj.find_by_name(".strtab")
        write_order.concat(@elf_obj.select_by_names(RELOCATION_SECTION_NAMES))
        write_order << @elf_obj.find_by_name(".shstrtab")
        write_order.compact
      end
      def write_section_index(section_name) = @write_sections.index { it.section_name == section_name }

      def write_shared_dynamic_sections(file:)
        if interp_section
          interp_offset = file.pos
          file.write(interp_section.body)
          size = file.pos - interp_offset
          interp_section.header.set!(offset: interp_offset, size:)
        end
        
        dynstr_offset = file.pos
        file.write(dynstr_section.body.build)
        size = file.pos - dynstr_offset
        dynstr_section.header.set!(offset: dynstr_offset, size:)

        dynsym_offset = file.pos
        dynsym_section.body.each { |dynsym| file.write(dynsym.build) }
        size = file.pos - dynsym_offset
        dynsym_section.header.set!(offset: dynsym_offset, size:)

        dynamic_offset = file.pos
        dynamic_section.body.each { |dynamic| file.write(dynamic.build) }
        size = file.pos - dynamic_offset
        dynamic_section.header.set!(offset: dynamic_offset, size:)
      end
      
      def ref_index(section_name)
        ref_name = section_name.split(".").filter { |sn| !sn.empty? && sn != "rel" && sn != "rela" }
        ref_name = "." + ref_name.join(".")
        ref = @write_sections.find { |s| s.section_name == ref_name }
        raise Caotral::Binary::ELF::Error, "cannot find reference section for #{section_name}" if ref.nil?
        write_section_index(ref.section_name)
      end

      def link_index(section_name)
        case section_name
        when ".symtab"
          write_section_index(".strtab")
        when ".dynsym", ".dynamic"
          write_section_index(".dynstr")
        else
          nil
        end
      end

      def program_header_flags(flag) = Caotral::Binary::ELF::ProgramHeader::PF[flag.to_sym]
      def elf_type = Caotral::Binary::ELF::Header::TYPE[@shared || @pie ? :DYN : :EXEC]

      def text_section = @text_section ||= @write_sections.find { |s| ".text" === s.section_name.to_s }
      def rel_sections = @rel_sections ||= @write_sections.select { RELOCATION_SECTION_NAMES.include?(it.section_name) }
      def symtab_section = @symtab_section ||= @write_sections.find { |s| ".symtab" === s.section_name.to_s }
      def strtab_section = @strtab_section ||= @write_sections.find { |s| ".strtab" === s.section_name.to_s }
      def shstrtab_section = @shstrtab_section ||= @write_sections.find { |s| ".shstrtab" === s.section_name.to_s }
      def dynstr_section = @dynstr_section ||= @write_sections.find { |s| ".dynstr" === s.section_name.to_s }
      def dynsym_section = @dynsym_section ||= @write_sections.find { |s| ".dynsym" === s.section_name.to_s }
      def dynamic_section = @dynamic_section ||= @write_sections.find { |s| ".dynamic" === s.section_name.to_s }
      def interp_section = @interp_section ||= @write_sections.find { |s| ".interp" === s.section_name.to_s }
    end
  end
end
