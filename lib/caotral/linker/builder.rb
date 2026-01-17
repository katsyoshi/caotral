require "set"
require "caotral/binary/elf"

module Caotral
  class Linker
    class Builder
      SYMTAB_BIND = { locals: 0, globals: 1, weaks: 2, }.freeze
      BIND_BY_VALUE = SYMTAB_BIND.invert.freeze
      RELOCATION_SECTION_NAMES = [".rela.text", ".rel.text"].freeze
      attr_reader :symbols

      def initialize(elf_objs:)
        @elf_objs = elf_objs
        @symbols = { locals: Set.new, globals: Set.new, weaks: Set.new }
      end

      def build
        raise Caotral::Binary::ELF::Error, "no ELF objects to link" if @elf_objs.empty?
        elf = Caotral::Binary::ELF.new
        elf_obj = @elf_objs.first
        first_text = elf_obj.find_by_name(".text")
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
        rel_sections = []
        elf.header = elf_obj.header.dup
        strtab_names = []
        text_offsets = {}
        text_offset = 0
        sym_by_elf = Hash.new { |h, k| h[k] = [] }
        @elf_objs.each do |elf_obj|
          text = elf_obj.find_by_name(".text")
          unless text.nil?
            text_section.body << text.body
            text_offsets[elf_obj.object_id] = text_offset
            size = text.body.bytesize
            text_offset += size
          end
          strtab = elf_obj.find_by_name(".strtab")
          strtab.body.names.split("\0").each { |name| strtab_names << name } unless strtab.nil?
          symtab = elf_obj.find_by_name(".symtab")
          base_index = nil
          unless symtab.nil?
            base_index = symtab_section.body.size
            symtab.body.each_with_index do |st, index|
              sym = Caotral::Binary::ELF::Section::Symtab.new
              name, info, other, shndx, value, size = st.build.unpack("L<CCS<Q<Q<")
              sym_by_elf[elf_obj] << sym
              value += text_offsets.fetch(elf_obj.object_id, 0) if shndx != 0
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
        elf.sections << null_section

        text_section.header.set!(
          type: 1,
          flags: 6,
          addralign: 16
        )

        elf.sections << text_section
        strtab_section.header.set!(type: 3, flags: 0, addralign: 1, entsize: 0)
        elf.sections << strtab_section
        symtab_section.body.each do |sym|
          next if sym.shndx == 0
          name = strtab_section.body.offset_of(sym.name_string)
          sym.set!(name:)
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

        elf.sections << symtab_section

        rel_sections.each { |s| elf.sections << s.dup }

        shstrtab_section.header.set!(
          type: 3,
          flags: 0,
          addralign: 1,
          entsize: 0
        )
        shstrtab_section_names = elf.sections.map(&:section_name).join("\0") + "\0"
        shstrtab_section.body.names = shstrtab_section_names
        elf.sections << shstrtab_section

        @elf_objs.first.without_sections([".text", ".strtab", ".symtab", ".shstrtab", /\.rela?\./]).each do |section|
          elf.sections << section.dup
        end
        section_map = Hash.new { |h, k| h[k] = {} }
        @elf_objs.each do |elf_obj|
          elf_obj.sections.each_with_index do |section, index|
            newndx = elf.sections.index { |s| s.section_name == section.section_name }
            section_map[elf_obj][index] = newndx unless newndx.nil?
          end
        end

        old_ids = old_syms.map(&:object_id)

        resolved_index = {}
        symtab_section.body.each_with_index do |sym, index|
          old_index = old_ids.index(sym.object_id)
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
        elf.select_by_names(RELOCATION_SECTION_NAMES).each do |rel_section|
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
            link: elf.sections.index(symtab_section),
            info: ref_index(elf, rel_section.section_name),
            addralign: 8,
            entsize: rel_entsize(rel_section)
          )
        end

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
      def ref_index(elf_obj, section_name)
        raise Caotral::Binary::ELF::Error, "invalid section name: #{section_name}" if section_name.nil?
        ref = elf_obj.select_by_names(section_name.split(".").filter { |sn| !sn.empty? && sn != "rel" && sn != "rela" }.map { "." + it }).first
        elf_obj.index(ref.section_name)
      end

      def rel_type(section) = section.section_name&.start_with?(".rela.") ? 4 : 9
      def rel_entsize(section) = section.section_name&.start_with?(".rela.") ? 24 : 16
    end
  end
end
