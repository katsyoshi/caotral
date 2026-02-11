require "set"
require "caotral/binary/elf"

module Caotral
  class Linker
    class Builder
      include Caotral::Binary::ELF::Utils
      R_X86_64_64 = 1
      R_X86_64_PC32 = 2
      R_X86_64_PLT32 = 4
      R_X86_64_RELATIVE = 8
      SYMTAB_BIND = { locals: 0, globals: 1, weaks: 2, }.freeze
      BIND_BY_VALUE = SYMTAB_BIND.invert.freeze
      RELOCATION_SECTION_NAMES = [".rela.text", ".rel.text", ".rela.data", ".rel.data"].freeze
      ALLOW_RELOCATION_TYPES = [R_X86_64_PC32, R_X86_64_PLT32].freeze
      GENERATED_SECTION_NAMES = [".text", ".data", ".strtab", ".symtab", ".shstrtab", /\.rela?\./, ".dynstr", ".dynsym", ".dynamic", ".interp", ".rela.dyn"].freeze
      SHT = Caotral::Binary::ELF::SectionHeader::SHT
      SHF = Caotral::Binary::ELF::SectionHeader::SHF

      attr_reader :symbols

      def initialize(elf_objs:, executable: true, debug: false, shared: false, pie: false)
        @elf_objs = elf_objs
        @executable, @debug, @shared, @pie = executable, debug, shared, pie
        @symbols = { locals: Set.new, globals: Set.new, weaks: Set.new }
        _mode!
      end

      def build
        raise Caotral::Binary::ELF::Error, "no ELF objects to link" if @elf_objs.empty?
        elf = Caotral::Binary::ELF.new
        elf_obj = @elf_objs.first
        null_section = Caotral::Binary::ELF::Section.new(
          body: nil,
          section_name: "",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        text_section = Caotral::Binary::ELF::Section.new(
          body: String.new,
          section_name: ".text",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        data_section = Caotral::Binary::ELF::Section.new(
          body: String.new,
          section_name: ".data",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        strtab_section = Caotral::Binary::ELF::Section.new(
          body: Caotral::Binary::ELF::Section::Strtab.new("\0".b),
          section_name: ".strtab",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        symtab_section = Caotral::Binary::ELF::Section.new(
          body: [],
          section_name: ".symtab",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        shstrtab_section = Caotral::Binary::ELF::Section.new(
          body: Caotral::Binary::ELF::Section::Strtab.new("\0".b),
          section_name: ".shstrtab",
          header: Caotral::Binary::ELF::SectionHeader.new
        )
        rela_dyn_section = Caotral::Binary::ELF::Section.new(
          body: [],
          section_name: ".rela.dyn",
          header: Caotral::Binary::ELF::SectionHeader.new
        )

        data_section.header.set!(type: SHT[:progbits], flags: SHF[:ALLOC] | SHF[:WRITE], addralign: 8)

        start_bytes = [0xe8, *[0] * 4, 0x48, 0x89, 0xc7, 0x48, 0xc7, 0xc0, 0x3c, 0x00, 0x00, 0x00, 0x0f, 0x05]
        exec_text_offset = 0x1000
        base_addr = 0x400000
        base_addr = 0 if @pie
        unless @executable
          start_bytes = []
          base_addr = 0
        end
        vaddr = base_addr + exec_text_offset
        start_len = start_bytes.length
        sections = []
        rel_sections = []
        elf.header = elf_obj.header.dup
        strtab_names = []
        text_offsets = {}
        data_offsets = {}
        text_offset = 0
        data_offset = 0
        sym_by_elf = Hash.new { |h, k| h[k] = [] }
        @elf_objs.each do |elf_obj|
          text = elf_obj.find_by_name(".text")
          unless text.nil?
            text_section.body << text.body
            text_offsets[elf_obj.object_id] = text_offset
            size = text.body.bytesize
            text_offset += size
          end
          data = elf_obj.find_by_name(".data")
          unless data.nil?
            data_section.body << data.body
            data_offsets[elf_obj.object_id] = data_offset
            data_offset += data.body.bytesize
          end
          strtab = elf_obj.find_by_name(".strtab")
          strtab.body.names.split("\0").each { |name| strtab_names << name } unless strtab.nil?
          symtab = elf_obj.find_by_name(".symtab")
          base_index = nil
          unless symtab.nil?
            base_index = symtab_section.body.size
            text_index = elf_obj.sections.index(text) unless text.nil?
            data_index = elf_obj.sections.index(data) unless data.nil?

            symtab.body.each_with_index do |st, index|
              sym = Caotral::Binary::ELF::Section::Symtab.new
              name, info, other, shndx, value, size = st.build.unpack("L<CCS<Q<Q<")
              sym_by_elf[elf_obj] << sym
              value += text_offsets.fetch(elf_obj.object_id, 0) if shndx == text_index
              value += data_offsets.fetch(elf_obj.object_id, 0) if shndx == data_index
              sym.set!(name:, info:, other:, shndx:, value:, size:)
              sym.name_string = strtab.body.lookup(name) unless strtab.nil?
              symtab_section.body << sym
            end
          end
          rels = elf_obj.select_by_names(RELOCATION_SECTION_NAMES).map do |section|
            rel_section = Caotral::Binary::ELF::Section.new(
              body: [],
              section_name: section.section_name,
              header: Caotral::Binary::ELF::SectionHeader.new
            )
            section.body.each do |rel|
              if rel.type == R_X86_64_64
                base_offset = case section.section_name.to_s
                              when /\.rela?\.text/
                                vaddr + start_len + text_offsets.fetch(elf_obj.object_id, 0)
                              when /\.rela?\.data/
                                vaddr + text_offset + data_offsets.fetch(elf_obj.object_id, 0) + start_len
                              else 0
                              end
                offset = rel.offset + base_offset
                sym = symtab_section.body[sym_index = base_index.nil? ? rel.sym : base_index + rel.sym]
                sym_addr = if sym.shndx == text_index
                             vaddr + sym.value
                           elsif sym.shndx == data_index
                             vaddr + text_offset + sym.value + start_len
                           else
                             0
                           end
                addend = sym_addr - base_addr
                rela_dyn_section.body << Caotral::Binary::ELF::Section::Rel.new.set!(offset:, info: (0 << 32) | R_X86_64_RELATIVE, addend:)
                next
              end
              offset = rel.offset + text_offsets.fetch(elf_obj.object_id, 0)
              addend = rel.addend? ? rel.addend : nil
              new_rel = Caotral::Binary::ELF::Section::Rel.new(addend: rel.addend?)
              sym = base_index.nil? ? rel.sym : base_index + rel.sym
              info = (sym << 32) | rel.type
              new_rel.set!(offset:, info:, addend:)
              rel_section.body << new_rel
            end
            rel_section
          end
          rel_sections += rels
        end
        strtab_section.body.names = strtab_names.to_a.sort.join("\0") + "\0"
        sections << null_section

        main_sym = symtab_section.body.find { |sym| sym.name_string == "main" }
        raise Caotral::Binary::ELF::Error, "main function not found" if @executable && main_sym.nil?
        main_offset = main_sym.nil? ? 0 : main_sym.value + start_len
        start_bytes[1, 4] = num2bytes((main_offset - 5), 4) if @executable
        text_section.body.prepend(start_bytes.pack("C*"))

        text_section.header.set!(
          type: 1,
          flags: 6,
          addr: vaddr,
          offset: exec_text_offset,
          size: text_section.body.bytesize,
          addralign: 16
        )

        sections << text_section
        strtab_section.header.set!(type: 3, flags: 0, addralign: 1, entsize: 0)
        sections << data_section
        sections << strtab_section
        text_index = sections.index(text_section)
        symtab_section.body.each do |sym|
          next if sym.shndx == 0
          name = strtab_section.body.offset_of(sym.name_string)
          value = sym.value + (text_index == sym.shndx ? start_len : 0)
          sym.set!(name:, value:)
        end

        old_syms = symtab_section.body.dup
        symtab_section.body.sort_by! { |sym| sym.info >> 4 }
        local_count = symtab_section.body.count { |sym| (sym.info >> 4) == SYMTAB_BIND[:locals] }

        symtab_section.header.set!(
          type: 2,
          flags: 0,
          link: elf.sections.index(strtab_section),
          info: local_count,
          addralign: 8,
          entsize: 24
        )

        sections += build_pie_sections if @pie
        if dynamic?
          dynstr, dynsym = build_shared_dynamic_sections
          sections << dynstr
          sections << dynsym
          sections << build_hash_section if @pie
          sections << rela_dyn_section
          sym = sections.index(dynsym)
          rela_dyn_section.header.set!(flags: SHF[:ALLOC], link: sym, type: rel_type(rela_dyn_section), info: 0, addralign: 8, entsize: rel_entsize(rela_dyn_section))
          sections << build_dynamic_section
        end
        sections << symtab_section

        rel_sections.each { |s| sections << s.dup }

        shstrtab_section.header.set!(
          type: 3,
          flags: 0,
          addralign: 1,
          entsize: 0
        )

        @elf_objs.first.without_sections(GENERATED_SECTION_NAMES).each do |section|
          sections << section.dup
        end

        sections << shstrtab_section

        shstrtab_section_names = [*sections.map(&:section_name), "\0"].join("\0")
        shstrtab_section.body.names = shstrtab_section_names

        section_map = Hash.new { |h, k| h[k] = {} }
        @elf_objs.each do |elf_obj|
          elf_obj.sections.each_with_index do |section, index|
            newndx = sections.index { |s| s.section_name == section.section_name }
            section_map[elf_obj][index] = newndx unless newndx.nil?
          end
        end

        resolved_index = {}
        symtab_section.body.each_with_index do |sym, index|
          name = sym.name_string
          next if name.empty? || sym.shndx == 0 || sym.bind != 1
          resolved_index[name] ||= index
        end

        sym_by_elf.each do |elf_obj, syms|
          syms.each do |sym|
            next if sym.shndx == 0
            shndx = section_map[elf_obj][sym.shndx]
            sym.set!(shndx:)
          end
        end

        rel_sections.each do |rel_section|
          rel_section.body.each do |rel|
            orig_sym = old_syms[rel.sym]
            next if orig_sym.nil?
            name = orig_sym.name_string
            new_index = resolved_index[name]
            next if new_index.nil?
            rel.set!(info: (new_index << 32) | rel.type)
          end

          rel_section.header.set!(
            type: rel_type(rel_section),
            flags: 0,
            link: sections.index(symtab_section),
            info: ref_index(sections, rel_section.section_name),
            addralign: 8,
            entsize: rel_entsize(rel_section)
          )
        end

        rel_sections.each do |rel|
          target = sections[rel.header.info]
          bytes = target.body.dup
          symtab_body = symtab_section.body
          rel.body.each do |entry|
            next unless ALLOW_RELOCATION_TYPES.include?(entry.type)
            sym = symtab_body[entry.sym]
            next if sym.nil? || sym.shndx == 0
            target_addr = target == text_section ? vaddr : target.header.addr
            sym_addr = sym.shndx >= 0xff00 ? sym.value : sections[sym.shndx].then { |st| st.header.addr + sym.value }
            sym_offset = entry.offset + start_len
            sym_addend = entry.addend? ? entry.addend : bytes[sym_offset, 4].unpack1("l<")
            value = sym_addr + sym_addend - (target_addr + sym_offset)
            bytes[sym_offset, 4] = [value].pack("l<")
          end
          target.body = bytes
        end

        sections = sections.reject { |section| RELOCATION_SECTION_NAMES.any? { |name| name === section.section_name.to_s } } if @executable
        sections.each { |section| elf.sections << section }

        elf
      end

      def resolve_symbols
        @elf_objs.each do |elf_obj|
          elf_obj.find_by_name(".symtab").body.each do |symtab|
            name = symtab.name_string
            next if name.empty?
            info = symtab.info
            bind = BIND_BY_VALUE.fetch(info >> 4)
            if bind == :globals && @symbols[bind].include?(name) && symtab.shndx != 0
              raise Caotral::Binary::ELF::Error,"cannot add into globals: #{name}"
            end
            @symbols[bind] << name
          end
        end
        @symbols
      end

      private

      def build_shared_dynamic_sections
        dynstr_section = Caotral::Binary::ELF::Section.new(
          body: Caotral::Binary::ELF::Section::Strtab.new("\0".b),
          section_name: ".dynstr",
          header: Caotral::Binary::ELF::SectionHeader.new
        )

        dynstr_section.header.set!(type: SHT[:strtab], flags: SHF[:ALLOC], addralign: 1, entsize: 0)

        dynsym_section = Caotral::Binary::ELF::Section.new(
          body: [Caotral::Binary::ELF::Section::Symtab.new],
          section_name: ".dynsym",
          header: Caotral::Binary::ELF::SectionHeader.new
        )

        dynsym_section.header.set!(info: 1, type: SHT[:dynsym], flags: SHF[:ALLOC], addralign: 8, entsize: 24)

        [dynstr_section, dynsym_section,]
      end

      def build_pie_sections
        interp_section = Caotral::Binary::ELF::Section.new(
          body: "/lib64/ld-linux-x86-64.so.2\0".b,
          section_name: ".interp",
          header: Caotral::Binary::ELF::SectionHeader.new
        )

        interp_section.header.set!(type: SHT[:progbits], addralign: 1, flags: SHF[:ALLOC], entsize: 0)
        [interp_section]
      end

      def build_hash_section
        hash_section = Caotral::Binary::ELF::Section.new(
          body: Caotral::Binary::ELF::Section::Hash.new(nchain: 1),
          section_name: ".hash",
          header: Caotral::Binary::ELF::SectionHeader.new
        )

        hash_section.header.set!(type: SHT[:hash], flags: SHF[:ALLOC], addralign: 4, entsize: 4)
        hash_section
      end

      def build_dynamic_section
        tag_types = Caotral::Binary::ELF::Section::Dynamic::TAG_TYPES
        dynamic_section = Caotral::Binary::ELF::Section.new(
          body: [
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:HASH], un: 0),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:RELA], un: 0),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:RELASZ], un: 0),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:RELAENT], un: 24),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:STRTAB]),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:STRSZ]),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:SYMTAB]),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:SYMENT], un: 24),
            Caotral::Binary::ELF::Section::Dynamic.new.set!(tag: tag_types[:TEXTREL], un: 0),
            Caotral::Binary::ELF::Section::Dynamic.new
          ],
          section_name: ".dynamic",
          header: Caotral::Binary::ELF::SectionHeader.new
        )

        dynamic_section.header.set!(type: SHT[:dynamic], flags: SHF[:ALLOC] | SHF[:WRITE], addralign: 8, entsize: 16)
        dynamic_section
      end

      def ref_index(sections, section_name)
        raise Caotral::Binary::ELF::Error, "invalid section name: #{section_name}" if section_name.nil?
        ref_names = "." + section_name.split(".").filter { |sn| !sn.empty? && sn != "rel" && sn != "rela" }.join(".")
        ref = sections.find { |s| ref_names === s.section_name.to_s }
        sections.index(ref)
      end

      def rel_type(section) = section.section_name&.start_with?(".rela.") ? 4 : 9
      def rel_entsize(section) = section.section_name&.start_with?(".rela.") ? 24 : 16
      def _mode!
        @executable = false if @shared
        raise Caotral::Binary::ELF::Error, "disallow both mode: shared and PIE" if @pie && @shared
      end

      def dynamic? = @shared || @pie
    end
  end
end
