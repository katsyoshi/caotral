module Caotral
  class Linker
    class ELF
      class Section
        class Rel
          include Caotral::Assembler::ELF::Utils
          def initialize(addend: true)
            @offset = num2bytes(0, 8)
            @info = num2bytes(0, 8)
            @addend = addend ? num2bytes(0, 8) : false
          end

          def set!(offset: nil, info: nil, addend: nil)
            @offset = num2bytes(offset, 8) if check(offset, 8)
            @info = num2bytes(info, 8) if check(info, 8)
            @addend = num2bytes(addend, 8) if check(addend, 8)
            self
          end

          def build = bytes.flatten.pack("C*")
          def offset = @offset.pack("C*").unpack1("Q<")
          def info = @info.pack("C*").unpack1("Q<")
          def addend
            raise "No addend field in this REL entry" unless addend?
            @addend.pack("C*").unpack1("Q<")
          end
          def sym = @info.pack("C*").unpack1("Q<") >> 32
          def type = @info.pack("C*").unpack1("Q<") & 0xffffffff
          def addend? = !!@addend

          private def bytes = addend? ? [@offset, @info, @addend] : [@offset, @info]
        end
      end
    end
  end
end
