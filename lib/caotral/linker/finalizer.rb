require "caotral/binary/elf"

require_relative "error"

module Caotral
  class Linker
    class Finalizer
      REL_TYPES = Caotral::Binary::ELF::Section::Rel::TYPES.freeze
      ALLOW_RELOCATION_TYPES = [REL_TYPES[:AMD64_PC32], REL_TYPES[:AMD64_PLT32]].freeze

      def initialize(elf:, metadata:, shared:, executable:, pie:, debug:)
        @elf, @metadata = elf, metadata
        @shared, @executable, @pie = shared, executable, pie
      end

      def apply!
        finalize_entry!
        finalize_plt_relocations!
        finalize_text_relocations!
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

      def text = @elf.find_by_name(".text")
      def plt = @elf.find_by_name(".plt")
      def rela_plt = @elf.find_by_name(".rela.plt")
      def got_plt = @elf.find_by_name(".got.plt")
      def dynsym = @elf.find_by_name(".dynsym")
      def symtab = @elf.find_by_name(".symtab")
      def dynstr = @elf.find_by_name(".dynstr")
      def pending_text_relocations = @metadata.fetch(:pending_text_relocations, [])
      def got_plt_offsets = @metadata.fetch(:got_plt_offsets, {})
    end
  end
end
