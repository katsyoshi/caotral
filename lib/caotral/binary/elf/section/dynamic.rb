require "caotral/binary/elf/utils"

module Caotral
  module Binary
    class ELF
      class Section
        class Dynamic
          include Caotral::Binary::ELF::Utils
          TAG_TYPES = {
            NULL: 0,
            NEEDED: 1,
            PLTRELSZ: 2,
            PLTGOT: 3,
            HASH: 4,
            STRTAB: 5,
            SYMTAB: 6,
            RELA: 7,
            RELASZ: 8,
            RELAENT: 9,
            STRSZ: 10,
            SYMENT: 11,
            PLTREL: 20,
            TEXTREL: 22,
            JMPREL: 23,
          }.freeze
          TAG_TYPES_BY_V = TAG_TYPES.invert.freeze

          def initialize
            @tag = num2bytes(0, 8)
            # d_un is a C union. Depending on d_tag, interpret this 8-byte field as either
            # a pointer (d_ptr) or an integer value (d_val).
            @un = num2bytes(0, 8)
          end

          def set!(tag: nil, un: nil)
            @tag = num2bytes(tag, 8) if check(tag, 8)
            @un = num2bytes(un, 8) if check(un, 8)
            self
          end

          def tag = @tag.pack("C*").unpack1("Q<")
          def un = @un.pack("C*").unpack1("Q<")
          def null? = tag == TAG_TYPES[:NULL]
          def rela? = tag == TAG_TYPES[:RELA]
          def rela_size? = tag == TAG_TYPES[:RELASZ]
          def rela_ent? = tag == TAG_TYPES[:RELAENT]
          def jmp_rel? = tag == TAG_TYPES[:JMPREL]
          def plt_rel? = tag == TAG_TYPES[:PLTREL]
          def plt_rel_size? = tag == TAG_TYPES[:PLTRELSZ]
          def plt_got? = tag == TAG_TYPES[:PLTGOT]
          def needed? = tag == TAG_TYPES[:NEEDED]

          private def bytes = [@tag, @un]
        end
      end
    end
  end
end
