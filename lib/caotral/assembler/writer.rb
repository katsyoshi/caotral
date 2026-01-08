require "caotral/binary/elf"

module Caotral
  class Assembler
    class Writer
      def self.write!(elf_obj:, output:, debug: false) = new(elf_obj:, output:, debug:).write
      def initialize(elf_obj:, output:, debug: false) = @elf_obj, @output, @debug = elf_obj, output, debug

      def write(output: @output) = output
    end
  end
end
