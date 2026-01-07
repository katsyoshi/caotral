require "caotral/binary/elf"

module Caotral
  class Assembler
    class Builder
      def initialize(instructions:) = @instructions = instructions

      def build
        elf = Caotral::Binary::ELF.new
        elf.header = Caotral::Binary::ELF::Header.new
        elf
      end
    end
  end
end
