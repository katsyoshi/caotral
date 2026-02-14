require "caotral/binary/elf/utils"
module Caotral
  module Binary
    class ELF
      class Section
        class Rel
          include Caotral::Binary::ELF::Utils
          TYPES = {
            AMD64_NONE: 0,
            AMD64_64: 1,
            AMD64_PC32: 2,
            AMD64_GOT32: 3,
            AMD64_PLT32: 4,
            AMD64_COPY: 5,
            AMD64_GLOB_DAT: 6,
            AMD64_JUMP_SLOT: 7,
            AMD64_RELATIVE: 8,
          }.freeze
          TYPES_BY_V = TYPES.invert.freeze

          def initialize(addend: true)
            @offset = num2bytes(0, 8)
            @info = num2bytes(0, 8)
            @addend = addend ? num2bytes(0, 8) : false
          end

          def set!(offset: nil, info: nil, addend: nil)
            @offset = num2bytes(offset, 8) if check(offset, 8)
            @info = num2bytes(info, 8) if check(info, 8)
            @addend = [addend].pack("q<").unpack("C*") if check(addend, 8)
            self
          end

          def build = bytes.flatten.pack("C*")
          def offset = @offset.pack("C*").unpack1("Q<")
          def info = @info.pack("C*").unpack1("Q<")
          def addend
            raise "No addend field in this REL entry" unless addend?
            @addend.pack("C*").unpack1("q<")
          end
          def sym = @info.pack("C*").unpack1("Q<") >> 32
          def type = @info.pack("C*").unpack1("Q<") & 0xffffffff
          def type_name = TYPES_BY_V[type]
          def addend? = !!@addend

          private def bytes = addend? ? [@offset, @info, @addend] : [@offset, @info]
        end
      end
    end
  end
end
