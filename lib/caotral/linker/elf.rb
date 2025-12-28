require_relative "elf/header"
require_relative "elf/sections"

module Caotral
  class Linker
    class ELF
      attr_reader :sections, :header
      def initialize
        @sections = Caotral::Linker::ELF::Sections.new
        @header = Caotral::Linker::ELF::Header.new
      end
    end
  end
end
