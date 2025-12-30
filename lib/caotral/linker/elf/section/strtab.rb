module Caotral
  class Linker
    class ELF
      class Section
        class Strtab
          include Caotral::Assembler::ELF::Utils
          attr_reader :names
          def initialize(names = "\0main\0", **opts) = @names = names
          def build = @names.bytes.pack("C*")
        end
      end
    end
  end
end
