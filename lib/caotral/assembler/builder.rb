require "caotral/binary/elf"

require_relative "builder/text"

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
