require "caotral/binary/elf"

module Caotral
  class Linker
    class Writer
      include Caotral::Binary::ELF::Utils
      REL_TYPES = Caotral::Binary::ELF::Section::Rel::TYPES.freeze
      ALLOW_RELOCATION_TYPES = [REL_TYPES[:AMD64_PC32], REL_TYPES[:AMD64_PLT32]].freeze
      RELOCATION_SECTION_NAMES = [".rela.text", ".rela.dyn", ".rela.data", ".rela.plt"].freeze
      attr_reader :elf_obj, :output, :entry, :debug
      def self.write!(elf_obj:, output:, entry: nil, debug: false, executable: true, shared: false)
        new(elf_obj:, output:, entry:, debug:, shared:, executable:).write
      end

      def initialize(elf_obj:, output:, entry: nil, debug: false, executable: true, shared: false, pie: false)
        @elf_obj, @output, @entry, @debug, @executable, @shared, @pie = elf_obj, output, entry, debug, executable, shared, pie
        @program_headers = []
        @write_sections = elf_obj.sections
      end

      def write
        f = File.open(@output, "wb")
        phoffset, phsize, ehsize = 64, 56, 64
        e_type = elf_type

        phs = program_headers

        lph = load_program_header
        iph = interp_program_header
        pph = pie_program_header
        dph = dynamic_program_header

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
        pph.set!(
          type: 6,
          offset: phoffset,
          vaddr: phoffset,
          paddr: phoffset,
          filesz: phsize * phnum,
          memsz: phsize * phnum,
          flags: program_header_flags(:R),
          align: 8
        ) if pph
        gap = [text_offset - f.pos, 0].max
        f.write("\0" * gap)

        write_elf_sections(file: f)

        if rela_plt_section && got_plt_section
          rela_plt_section&.body&.each do |rel|
            sym = symtab_section.body[rel.sym]
            dynsymndx = dynsym_section.body.index { |ds| ds.name_offset == dynstr_section.body.offset_of(sym.name_string) }
            raise Caotral::Binary::ELF::Error, "cannot find symbol #{sym.name_string} in .dynsym for relocation in .rela.plt" if dynsymndx.nil?
            rel.set!(
              info: (dynsymndx << 32) | REL_TYPES[:AMD64_JUMP_SLOT],
              offset: rel.offset + got_plt_section.header.addr
            )
          end
        end

        # relocation
        rel_sections.each do |rel|
          rel_offset = f.pos
          f.write(rel.build)
          rel_size = f.pos - rel_offset
          entsize = rel.body.respond_to?(:first) ? rel.body.first&.build&.bytesize.to_i : rel.header.entsize.to_i
          rel.header.set!(offset: rel_offset, size: rel_size, entsize:)
        end

        patch_dynamic_sections(file: f) if dynamic?
        patch_program_headers(file: f)
        write_program_headers(file: f)

        offset = f.pos
        names = @write_sections.map { |s| s.section_name.to_s }
        if names.last != ".shstrtab"
          raise Caotral::Binary::ELF::Error, "section header string table must be the last section"
        end
        shstrtab_section.body.names = names.uniq.join("\0") + "\0"
        shstrtab_section.header.set!(offset:, size: shstrtab_section.body.names.bytesize)
        f.write(shstrtab_section.body.names)
        shoffset = f.pos
        write_section_headers(file: f, shoffset:)
        output
      ensure
        f.close if f
      end

      private
      def rewrite_text_section(file:)
        cur = file.pos
        got_plt_offsets = @elf_obj.got_plt_offsets
        rel_text_sections.each do |rel|
          target = @elf_obj.sections[rel.header.info]
          bytes = target.body.dup
          symtab_body = symtab_section.body
          vaddr = target.header.addr
          file.seek(target.header.offset)
          rel.body.each do |entry|
            next unless ALLOW_RELOCATION_TYPES.include?(entry.type)
            sym = symtab_body[entry.sym]
            next if sym.nil?
            target_addr = target == text_section ? vaddr : target.header.addr
            sym_offset = entry.offset
            sym_addend = entry.addend? ? entry.addend : bytes[sym_offset, 4].unpack1("l<")
            sym_addr = if sym.shndx == 0
                         plt_section.header.addr + 16 * (((got_plt_offsets[entry.sym] - 24) / 8) + 1)
                       elsif sym.shndx >= 0xff00
                         sym.value
                       else
                         @elf_obj.sections[sym.shndx].header.addr + sym.value
                       end
            value = sym_addr + sym_addend - (target_addr + sym_offset)
            bytes[sym_offset, 4] = [value].pack("l<")
          end
          file.write(bytes)
        end
        file.seek(cur)
      end

      def patch_dynamic_sections(file:)
        dynamic_sections.each do |dyn|
          addr = text_section.header.addr + (dyn.header.offset - text_section.header.offset)
          dyn.header.set!(addr:)
        end

        cur = file.pos
        file.seek(dynsym_section.header.offset)
        dynsym_section.body.each do |dynsym_body|
          if dynsym_body.shndx != 0
            value = dynsym_body.value
            secndx = @write_sections[dynsym_body.shndx]&.header&.addr
            unless secndx.nil?
              value += secndx
              dynsym_body.set!(value:)
            end
          end
          file.write(dynsym_body.build)
        end
        file.seek(cur)

        if dynamic? && dynamic_section && rela_dyn_section
          rdsh = rela_dyn_section&.header
          bodies = dynamic_section.body
          bodies.delete_if { |dyn| dyn.tag == dynamic_tables[:TEXTREL] } unless rela_dyn_section.body.any? { |rel| rel.type == REL_TYPES[:AMD64_RELATIVE] }
          bodies.find { |dyn| dyn.tag == dynamic_tables[:RELA] }.set!(un: rdsh&.addr.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:RELASZ] }.set!(un: rdsh&.size.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:STRSZ] }&.set!(un: dynstr_section.header.size.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:SYMENT] }&.set!(un: dynsym_section.header.entsize.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:STRTAB] }&.set!(un: dynstr_section.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:SYMTAB] }&.set!(un: dynsym_section.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:HASH] }&.set!(un: hash_section.header.addr.to_i) if hash_section
          bodies.find { |dyn| dyn.tag == dynamic_tables[:PLTRELSZ] }&.set!(un: rela_plt_section.header.size.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:JMPREL] }&.set!(un: rela_plt_section.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == dynamic_tables[:PLTREL] }&.set!(un: dynamic_tables[:RELA])
          bodies.find { |dyn| dyn.tag == dynamic_tables[:PLTGOT] }&.set!(un: got_plt_section.header.addr.to_i)
          cur = file.pos
          file.seek(dynamic_section.header.offset)
          file.write(dynamic_section.build)
          file.seek(cur)
        end
      end

      def patch_program_headers(file:)
        if interp_program_header
          ish = interp_section.header
          interp_program_header.set!(
            offset: ish.offset,
            vaddr: 0,
            paddr: 0,
            filesz: ish.size,
            memsz: ish.size,
            flags: program_header_flags(:R),
            align: 1
          )
        end

        if dynamic_program_header
          dsh = dynamic_section.header
          dynamic_program_header.set!(
            offset: dsh.offset,
            filesz: dsh.size,
            memsz: dsh.size,
            vaddr: dsh.addr || 0,
            paddr: dsh.addr || 0,
            flags: program_header_flags(:R),
            align: dsh.addralign
          )
        end

        segment_start = text_section.header.offset
        segment_start = 0 if @pie
        segment_end = [text_section, rodata_section, data_section,].concat(dynamic_sections).compact.map { |s| s.header.offset + s.header.size }.max

        dynamic_filesz = segment_end - segment_start
        load_program_header.set!(filesz: dynamic_filesz, memsz: dynamic_filesz)
        load_program_header.set!(offset: 0, vaddr: 0, paddr: 0) if @pie
      end

      def write_program_headers(file:)
        phoffset = @elf_obj.header.phoffset
        phsize = @elf_obj.header.phsize
        cur = file.pos
        program_headers.each_with_index do |ph, idx|
          file.seek(phoffset + (idx * phsize))
          file.write(ph.build)
        end
        file.seek(cur)
      end

      def write_elf_sections(file:)
        text_offset = file.pos
        file.write(text_section.build)
        text_section.header.set!(
          offset: text_offset,
          size: text_section.body.bytesize,
          addr: text_section.header.addr
        )

        if rodata_section
          ordata_offset = file.pos
          file.write(rodata_section.build)
          rodata_section.header.set!(
            offset: ordata_offset,
            size: rodata_section.body.bytesize,
            addr: text_section.header.addr + (ordata_offset - text_section.header.offset)
          )
        end

        if data_section
          data_offset = file.pos
          file.write(data_section.build)
          data_section.header.set!(
            offset: data_offset,
            size: data_section.body.bytesize,
            addr: text_section.header.addr + (data_offset - text_section.header.offset)
          )
        end

        if plt_section
          plt_offset = file.pos
          file.write(plt_section.body.flatten.pack("C*"))
          size = file.pos - plt_offset
          plt_section.header.set!(
            offset: plt_offset,
            size:,
            addr: text_section.header.addr + (plt_offset - text_section.header.offset)
          )

          raise Caotral::Binary::ELF::Error, "missing .got.plt for .plt" if got_plt_section.nil?

          got_plt_offset = file.pos
          file.write(got_plt_section.body.flatten.pack("C*"))
          size = file.pos - got_plt_offset
          got_plt_section.header.set!(
            offset: got_plt_offset,
            size:,
            addr: text_section.header.addr + (got_plt_offset - text_section.header.offset)
          )
        end

        write_shared_dynamic_sections(file:) if dynamic?

        # section write
        symtab_offset = file.pos
        file.write(symtab_section.build)
        symtab_entsize = symtab_section.body.first&.build&.bytesize.to_i
        symtab_size = file.pos - symtab_offset
        symtab_section.header.set!(offset: symtab_offset, size: symtab_size, entsize: symtab_entsize)
        strtab_offset = file.pos
        file.write(strtab_section.build)
        strtab_section.header.set!(offset: strtab_offset, size: strtab_section.body.names.bytesize)
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

        pad_to_align(file:, align: dynstr_section.header.addralign)
        dynstr_offset = file.pos
        file.write(dynstr_section.body.build)
        size = file.pos - dynstr_offset
        dynstr_section.header.set!(offset: dynstr_offset, size:, addr: text_addr + (dynstr_offset - tsh.offset))

        pad_to_align(file:, align: dynsym_section.header.addralign)
        dynsym_offset = file.pos
        dynsym_section.body.each { |dynsym| file.write(dynsym.build) }
        size = file.pos - dynsym_offset
        dynsym_section.header.set!(offset: dynsym_offset, size:, addr: text_addr + (dynsym_offset - tsh.offset))

        if dynamic?
          pad_to_align(file:, align: hash_section.header.addralign)
          hash_offset = file.pos
          file.write(hash_section.body.build)
          size = file.pos - hash_offset
          hash_section.header.set!(offset: hash_offset, size:, addr: text_addr + (hash_offset - tsh.offset))
        end

        pad_to_align(file:, align: dynamic_section.header.addralign)
        dynamic_offset = file.pos
        dynamic_section.body.each { |dynamic| file.write(dynamic.build) }
        size = file.pos - dynamic_offset
        dynamic_section.header.set!(offset: dynamic_offset, size:, addr: text_addr + (dynamic_offset - tsh.offset))

        if plt_section
          current_offset = file.pos
          primary, *rest = plt_section.body
          plt_offset = plt_section.header.offset
          got_plt_offset = got_plt_section.header.offset
          file.seek(plt_offset)
          plt_addr = plt_section.header.addr
          got_plt_addr = got_plt_section.header.addr
          # only support x86-64 binaries with PLT
          primary[2..5] = [(got_plt_addr + 8) - (plt_addr + 6)].pack("l<").bytes
          primary[8..11] = [(got_plt_addr + 16) - (plt_addr + 12)].pack("l<").bytes
          slot_offset = 24
          rest.each_with_index do |entry, i|
            entry_addr = plt_addr + 16 + 16 * i
            slot_addr = got_plt_addr + slot_offset + 8 * i
            entry[2..5] = [slot_addr - (entry_addr + 6)].pack("l<").bytes
            entry[7..10] = [i].pack("l<").bytes
            entry[12..15] = [plt_addr - (entry_addr + 16)].pack("l<").bytes
          end
          file.write(primary.flatten.pack("C*"))
          file.write(rest.flatten.pack("C*"))

          file.seek(got_plt_offset)
          primary, secondary, third, *rest = got_plt_section.body
          primary = [dynamic_section.header.addr].pack("Q<").bytes
          rest.each_with_index { |_entry, i| rest[i] = [plt_addr + 22 + 16 * i].pack("Q<").bytes }
          file.write(primary.flatten.pack("C*"))
          file.write(secondary.flatten.pack("C*"))
          file.write(third.flatten.pack("C*"))
          file.write(rest.flatten.pack("C*"))
          file.seek(current_offset)
        end
        rewrite_text_section(file:) unless rel_text_sections.empty?
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

      def write_section_headers(file:, shoffset:)
        shnum = @write_sections.size
        shstrndx  = write_section_index(".shstrtab")
        symtabndx = write_section_index(".symtab")

        @elf_obj.header.set!(shoffset:, shnum:, shstrndx:)
        names = shstrtab_section.body
        @write_sections.each do |section|
          header = section.header
          lookup_name = section.section_name
          name = names.offset_of(lookup_name) || 0
          info, entsize = header.info, header.entsize
          link = link_index(section.section_name)
          link = header.link if link.nil?
          if [:rela, :rel].include?(header.type)
            if [".rela.dyn", ".rela.plt"].include?(section.section_name.to_s)
              entsize = 24
            elsif ".rela.text" == section.section_name.to_s
              info = write_section_index(".text")
              entsize = 24
              link = symtabndx
            else
              link = symtabndx
            end
            info = ref_index(section.section_name) unless ".rela.plt" == section.section_name.to_s
          end
          header.set!(name:, info:, link:, entsize:)
          file.write(section.header.build)
        end
        file.seek(0)
        file.write(@elf_obj.header.build)
      end

      def pad_to_align(file:, align:)
        pos = file.pos
        padding = (align - (pos % align)) % align
        file.write("\0" * padding)
      end

      def program_header_flags(flag) = Caotral::Binary::ELF::ProgramHeader::PF[flag.to_sym]
      def elf_type = Caotral::Binary::ELF::Header::TYPE[dynamic? ? :DYN : :EXEC]

      def non_executable? = (@shared || !@executable)
      def dynamic? = (@shared || @pie)

      def dynamic_tables = Caotral::Binary::ELF::Section::Dynamic::TAG_TYPES
      def program_headers
        return @program_headers unless @program_headers.empty?
        # PT_LOAD
        lph = Caotral::Binary::ELF::ProgramHeader.new
        lph.set!(type: 1)
        # PT_INTERP
        if interp_section
          iph = Caotral::Binary::ELF::ProgramHeader.new
          iph.set!(type: 3)
        end
        # PT_DYNAMIC
        if dynamic_section
          dph = Caotral::Binary::ELF::ProgramHeader.new
          dph.set!(type: 2)
        end
        # PT_PHDR
        if @pie
          pph = Caotral::Binary::ELF::ProgramHeader.new
          pph.set!(type: 6)
        end
        # ruby's dlopen support
        if dynamic?
          gsph = Caotral::Binary::ELF::ProgramHeader.new
          gsph.set!(type: 0x6474e551, flags: program_header_flags(:RW))
        end
        @program_headers = [pph, lph, iph, dph, gsph].compact
      end
      def pie_program_header = @pie_program_header ||= program_headers.find { |ph| ph.type == :PHDR }
      def load_program_header = @load_program_header ||= program_headers.find { |ph| ph.type == :LOAD }
      def interp_program_header = @interp_program_header ||= program_headers.find { |ph| ph.type == :INTERP }
      def dynamic_program_header = @dynamic_program_header ||= program_headers.find { |ph| ph.type == :DYNAMIC }

      def text_section = @text_section ||= @write_sections.find { |s| ".text" === s.section_name.to_s }
      def rel_sections = @rel_sections ||= @write_sections.select { |s| RELOCATION_SECTION_NAMES.include?(s.section_name.to_s) }
      def rel_text_sections = @rel_text_sections ||= @elf_obj.rel_texts
      def symtab_section = @symtab_section ||= @write_sections.find { |s| ".symtab" === s.section_name.to_s }
      def strtab_section = @strtab_section ||= @write_sections.find { |s| ".strtab" === s.section_name.to_s }
      def shstrtab_section = @shstrtab_section ||= @write_sections.find { |s| ".shstrtab" === s.section_name.to_s }
      def dynstr_section = @dynstr_section ||= @write_sections.find { |s| ".dynstr" === s.section_name.to_s }
      def dynsym_section = @dynsym_section ||= @write_sections.find { |s| ".dynsym" === s.section_name.to_s }
      def dynamic_section = @dynamic_section ||= @write_sections.find { |s| ".dynamic" === s.section_name.to_s }
      def interp_section = @interp_section ||= @write_sections.find { |s| ".interp" === s.section_name.to_s }
      def rela_dyn_section = @rela_dyn_section ||= @write_sections.find { |s| ".rela.dyn" === s.section_name.to_s }
      def data_section = @data_section ||= @write_sections.find { |s| ".data" === s.section_name.to_s }
      def rodata_section = @rodata_section ||= @write_sections.find { |s| ".rodata" === s.section_name.to_s }
      def hash_section = @hash_section ||= @write_sections.find { |s| ".hash" === s.section_name.to_s }
      def plt_section = @plt_section ||= @write_sections.find { |s| ".plt" === s.section_name.to_s }
      def got_plt_section = @got_plt_section ||= @write_sections.find { |s| ".got.plt" === s.section_name.to_s }
      def rela_plt_section = @rela_plt_section ||= @write_sections.find { |s| ".rela.plt" === s.section_name.to_s }

      def dynamic_sections = @dynamic_sections ||= [interp_section, dynstr_section, dynsym_section, hash_section, dynamic_section, rela_dyn_section, rela_plt_section].compact
    end
  end
end
