require "caotral/binary/elf/utils"
module Caotral
  module Binary
    class ELF
      class Section
        class Dynamic
          include Caotral::Binary::ELF::Utils
          TAG_TYPES = {
            NULL: 0,
            HASH: 4,
            RELA: 7,
            RELASZ: 8,
            RELAENT: 9,
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
          def null? = tag == TAG_TYPES[:NULL]

          private def bytes = [@tag, @un]
        end
      end
    end
  end
end
