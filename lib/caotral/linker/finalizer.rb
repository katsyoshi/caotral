require "caotral/binary/elf"

require_relative "error"

module Caotral
  class Linker
    class Finalizer
      REL_TYPES = Caotral::Binary::ELF::Section::Rel::TYPES.freeze

      def initialize(elf:, metadata:, shared:, executable:, pie:, debug:)
        @elf, @metadata = elf, metadata
        @shared, @executable, @pie = shared, executable, pie
      end

      def apply!
        finalize_entry!
        finalize_plt_relocations!
        @elf
      end

      def finalize_entry!
        text = @elf.find_by_name(".text")
        entry = @executable ? text&.header&.addr : 0
        @elf.header.set!(entry:)
      end

      def finalize_plt_relocations!
        rela_plt = @elf.find_by_name(".rela.plt")
        got_plt = @elf.find_by_name(".got.plt")
        dynsym = @elf.find_by_name(".dynsym")
        symtab = @elf.find_by_name(".symtab")
        dynstr = @elf.find_by_name(".dynstr")
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
    end
  end
end
