module Caotral
  class Linker
    class ELF
      class Section
        class Strtab
          include Caotral::Assembler::ELF::Utils
          attr_reader :names
          def initialize(names = "\0main\0", **opts) = @names = names
          def build = @names.bytes.pack("C*")
          def offset_of(name)
            offset = 0
            @names.split("\0").each do |n|
              return offset if n == name
              offset += n.bytesize + 1
            end
            nil
          end
        end
      end
    end
  end
end
