module Caotral
  class Linker
    class Finalizer
      def initialize(elf:, metadata:, shared:, executable:, pie:, debug:)
        @elf, @metadata = elf, metadata
        @shared, @executable, @pie = shared, executable, pie
      end

      def apply!
        text = @elf.find_by_name(".text")
        entry = @executable ? text&.header&.addr : 0
        @elf.header.set!(entry:)
        @elf
      end
    end
  end
end
