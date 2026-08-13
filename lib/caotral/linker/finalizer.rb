require "caotral/binary/elf"

require_relative "error"

module Caotral
  class Linker
    class Finalizer
      REL_TYPES = Caotral::Binary::ELF::Section::Rel::TYPES.freeze
      ALLOW_RELOCATION_TYPES = [REL_TYPES[:AMD64_PC32], REL_TYPES[:AMD64_PLT32]].freeze
      DYNAMIC_TABLES = Caotral::Binary::ELF::Section::Dynamic::TAG_TYPES

      def initialize(elf:, metadata:, shared:, executable:, pie:, debug:)
        @elf, @metadata = elf, metadata
        @shared, @executable, @pie = shared, executable, pie
      end

      def apply!
        finalize_entry!
        finalize_plt_relocations!
        finalize_text_relocations!
        finalize_relative_relocations!
        finalize_dynamic_sections! if dynamic?
        finalize_shared_sections! if dynamic? && plt
        finalize_section_headers!
        @elf
      end

      private
      def finalize_entry!
        entry = @executable ? text&.header&.addr : 0
        @elf.header.set!(entry:)
      end

      def finalize_plt_relocations!
        return unless rela_plt && got_plt
        rela_plt&.body&.each do |rel|
          sym = symtab.body[rel.sym]
          dynsymndx = dynsym.body.index { |ds| ds.name_offset == dynstr.body.offset_of(sym.name_string) }
          raise Caotral::Linker::Error, "cannot find symbol #{sym.name_string} in .dynsym for relocation in .rela.plt" if dynsymndx.nil?
          rel.set!(
            info: (dynsymndx << 32) | REL_TYPES[:AMD64_JUMP_SLOT],
            offset: rel.offset + got_plt.header.addr
          )
        end
      end

      def finalize_text_relocations!
        return unless pending_text_relocations && got_plt_offsets
        grouped_rels = pending_text_relocations.group_by { |rel| rel.header.info }
        grouped_rels.each do |target_index, rels|
          target = @elf.sections[target_index]
          bytes = target.body.dup
          symtab_body = symtab.body
          vaddr = target.header.addr
          rels.each do |rel|
            rel.body.each do |entry|
              next unless ALLOW_RELOCATION_TYPES.include?(entry.type)
              sym = symtab_body[entry.sym]
              next if sym.nil?
              target_addr = target == text ? vaddr : target.header.addr
              sym_offset = entry.offset
              sym_addend = entry.addend? ? entry.addend : bytes[sym_offset, 4].unpack1("l<")
              sym_addr = if sym.shndx == 0
                           plt.header.addr + 16 * (((got_plt_offsets[entry.sym] - 24) / 8) + 1)
                         elsif sym.shndx >= 0xff00
                           sym.value
                         else
                           @elf.sections[sym.shndx].header.addr + sym.value
                         end
              value = sym_addr + sym_addend - (target_addr + sym_offset)
              bytes[sym_offset, 4] = [value].pack("l<")
            end
          end
          target.body = bytes
        end
      end

      def finalize_relative_relocations!
        pending_relative_relocations.each do |rrh|
          symbol = rrh[:symbol]
          symbol_section = @elf.sections[symbol.shndx]
          target = rrh[:target]
          relocation = rrh[:relocation]
          relocation.set!(
            offset: target.header.addr + rrh[:target_offset],
            addend: symbol_section.header.addr + symbol.value + rrh[:addend]
          )
        end
      end

      def finalize_dynamic_sections!
        dynsym.body.each do |dynsym_body|
          if dynsym_body.shndx != 0
            value = dynsym_body.value
            secndx = @elf.sections[dynsym_body.shndx]&.header&.addr
            unless secndx.nil?
              value += secndx
              dynsym_body.set!(value:)
            end
          end
        end
        if dynamic? && dynamic && rela_dyn
          rdsh = rela_dyn&.header
          bodies = dynamic.body
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:RELA] }.set!(un: rdsh&.addr.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:RELASZ] }.set!(un: rdsh&.size.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:STRSZ] }&.set!(un: dynstr.header.size.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:SYMENT] }&.set!(un: dynsym.header.entsize.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:STRTAB] }&.set!(un: dynstr.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:SYMTAB] }&.set!(un: dynsym.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:HASH] }&.set!(un: hash_section.header.addr.to_i) if hash_section
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:PLTRELSZ] }&.set!(un: rela_plt.header.size.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:JMPREL] }&.set!(un: rela_plt.header.addr.to_i)
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:PLTREL] }&.set!(un: DYNAMIC_TABLES[:RELA])
          bodies.find { |dyn| dyn.tag == DYNAMIC_TABLES[:PLTGOT] }&.set!(un: got_plt.header.addr.to_i)
        end
      end

      def finalize_shared_sections!
        primary, *rest = plt.body
        plt_addr = plt.header.addr
        got_plt_addr = got_plt.header.addr
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
        primary = got_plt.body.first
        rest = got_plt.body.drop(3)
        primary.replace([dynamic.header.addr].pack("Q<").bytes)
        rest.each_with_index { |entry, i| entry.replace([plt_addr + 22 + 16 * i].pack("Q<").bytes) }
      end

      def finalize_section_headers!
        symtabndx = @elf.sections.index { |s| s.section_name == ".symtab" }
        names = shstrtab.body
        @elf.sections.each do |section|
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
              info = @elf.index(".text")
              entsize = 24
              link = symtabndx
            else
              link = symtabndx
            end
            info = ref_index(section.section_name) unless ".rela.plt" == section.section_name.to_s
          end
          header.set!(name:, info:, link:, entsize:)
        end
      end

      def ref_index(section_name)
        return 0 if section_name == ".rela.dyn"
        ref_name = section_name.split(".").filter { |sn| !sn.empty? && sn != "rel" && sn != "rela" }.join(".")
        index = @elf.index(".#{ref_name}")
        raise Caotral::Linker::Error, "cannot find reference section for #{section_name}" unless index
        index
      end

      def link_index(section_name)
        case section_name
        when ".symtab"
          @elf.index(".strtab")
        when ".dynsym", ".dynamic"
          @elf.index(".dynstr")
        when ".hash"
          @elf.index(".dynsym")
        else
          nil
        end
      end

      def text = @text ||= @elf.find_by_name(".text")
      def plt = @plt ||= @elf.find_by_name(".plt")
      def rela_plt = @rela_plt ||= @elf.find_by_name(".rela.plt")
      def got_plt = @got_plt ||= @elf.find_by_name(".got.plt")
      def dynsym = @dynsym ||= @elf.find_by_name(".dynsym")
      def symtab = @symtab ||= @elf.find_by_name(".symtab")
      def dynstr = @dynstr ||= @elf.find_by_name(".dynstr")
      def interp = @interp ||= @elf.find_by_name(".interp")
      def hash_section = @hash_section ||= @elf.find_by_name(".hash")
      def dynamic = @dynamic ||= @elf.find_by_name(".dynamic")
      def rela_dyn = @rela_dyn ||= @elf.find_by_name(".rela.dyn")
      def shstrtab = @shstrtab ||= @elf.find_by_name(".shstrtab")
      def pending_text_relocations = @pending_text_relocations ||= @metadata.fetch(:pending_text_relocations, [])
      def pending_relative_relocations = @pending_relative_relocations ||= @metadata.fetch(:pending_relative_relocations, [])
      def got_plt_offsets = @got_plt_offsets ||= @metadata.fetch(:got_plt_offsets, {})
      def dynamic? = (@shared || @pie)
    end
  end
end
