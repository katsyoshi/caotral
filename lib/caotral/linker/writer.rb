require "caotral/binary/elf"

module Caotral
  class Linker
    class Writer
      include Caotral::Binary::ELF::Utils
      R_X86_64_PC32 = 2
      R_X86_64_PLT32 = 4
      ALLOW_RELOCATION_TYPES = [R_X86_64_PC32, R_X86_64_PLT32].freeze
      RELOCATION_SECTION_NAMES = [".rela.text", ".rela.dyn", ".rela.data"].freeze
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
        # PT_PHDR
        pph = Caotral::Binary::ELF::ProgramHeader.new if @pie
        phs = [pph, lph, iph, dph].compact
        phnum = phs.size
        header = @elf_obj.header.set!(type: e_type, phoffset:, phnum:, phsize:, ehsize:)
        text_offset = text_section.header.offset
        align = 0x1000
        vaddr = text_section.header.addr
        paddr = vaddr
        type, flags = 1, program_header_flags(:RWX)
        filesz = text_section.body.bytesize
        memsz = filesz
        entry = non_executable? ? 0 : (@entry || vaddr)

        header.set!(entry:)
        lph.set!(type:, offset: text_offset, vaddr:, paddr:, filesz:, memsz:, flags:, align:)
        f.write(@elf_obj.header.build)
        phs.each { |ph| f.write(ph.build) }
        if pph
          pph.set!(
            type: 6,
            offset: phoffset,
            vaddr: phoffset,
            paddr: phoffset,
            filesz: phsize * phnum,
            memsz: phsize * phnum,
            flags: program_header_flags(:R),
            align: 8
          )
        end
        gap = [text_offset - f.pos, 0].max
        f.write("\0" * gap)
        f.write(text_section.body)
        if data_section
          data_offset = f.pos
          f.write(data_section.body)
          data_section.header.set!(
            offset: data_offset,
            size: data_section.body.bytesize,
            addr: text_section.header.addr + (data_offset - text_section.header.offset)
          )
        end
        if dynamic?
          write_shared_dynamic_sections(file: f)
        end

        if iph
          ish = interp_section.header
          iph.set!(type: 3, offset: ish.offset, vaddr: 0, paddr: 0, filesz: ish.size, memsz: ish.size, flags: program_header_flags(:R), align: 1)
        end

        if dph
          dsh = dynamic_section.header
          dph.set!(type: 2, offset: dsh.offset, filesz: dsh.size, memsz: dsh.size, vaddr: dsh.addr || 0, paddr: dsh.addr || 0, flags: program_header_flags(:R), align: dsh.addralign)
        end

        cur = f.pos
        phs.each_with_index do |ph, idx|
          next if ph == lph
          f.seek(phoffset + (idx * phsize))
          f.write(ph.build)
        end
        f.seek(cur)

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

        dynamic_sections.each do |dyn|
          addr = text_section.header.addr + (dyn.header.offset - text_section.header.offset)
          dyn.header.set!(addr:)
        end

        if dynamic? && dynamic_section && rela_dyn_section
          rdsh = rela_dyn_section&.header
          bodies = dynamic_section.body
          bodies.find { |dyn| dyn.tag == dynamic_tables[:RELA] }.set!(un: rdsh&.addr.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:RELASZ] }.set!(un: rdsh&.size.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:STRSZ] }&.set!(un: dynstr_section.header.size.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:SYMENT] }&.set!(un: dynsym_section.header.entsize.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:STRTAB] }&.set!(un: dynstr_section.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:SYMTAB] }&.set!(un: dynsym_section.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:HASH] }&.set!(un: hash_section.header.addr.to_i) if hash_section

          segment_start = text_section.header.offset
          segment_start = 0 if @pie
          segment_end = [text_section, data_section,].concat(dynamic_sections).compact.map { |s| s.header.offset + s.header.size }.max

          dynamic_filesz = segment_end - segment_start
          cur = f.pos
          lphndx = phs.index(lph)

          lph.set!(offset: 0, vaddr: 0, paddr: 0, filesz: dynamic_filesz, memsz: dynamic_filesz)
          f.seek(phoffset + phsize * lphndx)
          f.write(lph.build)
          f.seek(cur)

          cur = f.pos
          f.seek(dynamic_section.header.offset)
          dynamic_section.body.each { |dyn| f.write(dyn.build) }
          f.seek(cur)
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
        write_order << @elf_obj.find_by_name(".data")
        write_order << @elf_obj.find_by_name(".interp")
        write_order << @elf_obj.find_by_name(".dynstr")
        write_order << @elf_obj.find_by_name(".dynsym")
        write_order << @elf_obj.find_by_name(".hash")
        write_order << @elf_obj.find_by_name(".dynamic")
        write_order << @elf_obj.find_by_name(".symtab")
        write_order << @elf_obj.find_by_name(".strtab")
        write_order.concat(@elf_obj.select_by_names(RELOCATION_SECTION_NAMES))
        write_order << @elf_obj.find_by_name(".shstrtab")
        write_order.compact
      end
      def write_section_index(section_name) = @write_sections.index { it.section_name == section_name }

      def write_shared_dynamic_sections(file:)
        tsh = text_section&.header
        text_addr = tsh&.addr || 0
        if interp_section
          interp_offset = file.pos
          file.write(interp_section.body)
          size = file.pos - interp_offset
          interp_section.header.set!(offset: interp_offset, size:, addr: text_addr + (interp_offset - tsh.offset))
        end

        dynstr_offset = file.pos
        file.write(dynstr_section.body.build)
        size = file.pos - dynstr_offset
        dynstr_section.header.set!(offset: dynstr_offset, size:, addr: text_addr + (dynstr_offset - tsh.offset))

        dynsym_offset = file.pos
        dynsym_section.body.each { |dynsym| file.write(dynsym.build) }
        size = file.pos - dynsym_offset
        dynsym_section.header.set!(offset: dynsym_offset, size:, addr: text_addr + (dynsym_offset - tsh.offset))

        if @pie
          hash_offset = file.pos
          file.write(hash_section.body.build)
          size = file.pos - hash_offset
          hash_section.header.set!(offset: hash_offset, size:, addr: text_addr + (hash_offset - tsh.offset))
        end

        dynamic_offset = file.pos
        dynamic_section.body.each { |dynamic| file.write(dynamic.build) }
        size = file.pos - dynamic_offset
        dynamic_section.header.set!(offset: dynamic_offset, size:, addr: text_addr + (dynamic_offset - tsh.offset))
      end
      
      def ref_index(section_name)
        return 0 if section_name == ".rela.dyn"
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
        when ".hash"
          write_section_index(".dynsym")
        else
          nil
        end
      end

      def program_header_flags(flag) = Caotral::Binary::ELF::ProgramHeader::PF[flag.to_sym]
      def elf_type = Caotral::Binary::ELF::Header::TYPE[dynamic? ? :DYN : :EXEC]

      def non_executable? = (@shared || !@executable)
      def dynamic? = (@shared || @pie)

      def dynamic_tables = Caotral::Binary::ELF::Section::Dynamic::TAG_TYPES

      def text_section = @text_section ||= @write_sections.find { |s| ".text" === s.section_name.to_s }
      def rel_sections = @rel_sections ||= @write_sections.select { |s| RELOCATION_SECTION_NAMES.include?(s.section_name.to_s) }
      def symtab_section = @symtab_section ||= @write_sections.find { |s| ".symtab" === s.section_name.to_s }
      def strtab_section = @strtab_section ||= @write_sections.find { |s| ".strtab" === s.section_name.to_s }
      def shstrtab_section = @shstrtab_section ||= @write_sections.find { |s| ".shstrtab" === s.section_name.to_s }
      def dynstr_section = @dynstr_section ||= @write_sections.find { |s| ".dynstr" === s.section_name.to_s }
      def dynsym_section = @dynsym_section ||= @write_sections.find { |s| ".dynsym" === s.section_name.to_s }
      def dynamic_section = @dynamic_section ||= @write_sections.find { |s| ".dynamic" === s.section_name.to_s }
      def interp_section = @interp_section ||= @write_sections.find { |s| ".interp" === s.section_name.to_s }
      def rela_dyn_section = @rela_dyn_section ||= @write_sections.find { |s| ".rela.dyn" === s.section_name.to_s }
      def data_section = @data_section ||= @write_sections.find { |s| ".data" === s.section_name.to_s }
      def hash_section = @hash_section ||= @write_sections.find { |s| ".hash" === s.section_name.to_s }

      def dynamic_sections = @dynamic_sections ||= [interp_section, dynstr_section, dynsym_section, dynamic_section, rela_dyn_section].compact
    end
  end
end
