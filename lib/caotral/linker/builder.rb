require "set"
require "caotral/binary/elf"

module Caotral
  class Linker
    class Builder
      SYMTAB_BIND = { locals: 0, globals: 1, weaks: 2, }.freeze
      BIND_BY_VALUE = SYMTAB_BIND.invert.freeze
      attr_reader :symbols

      def initialize(elf_obj:)
        @elf_obj = elf_obj
        @symbols = { locals: Set.new, globals: Set.new, weaks: Set.new }
      end
      def resolve_symbols
        @elf_obj.find_by_name(".symtab").body.each do |symtab|
          name = symtab.name_string
          next if name.empty?
          info = symtab.info
          bind = BIND_BY_VALUE.fetch(info >> 4)
          if bind == :globals && @symbols[bind].include?(name)
            raise Caotral::Binary::ELF::Error,"cannot add into globals: #{name}"
          end
          @symbols[bind] << name
        end
        @symbols
      end
    end
  end
end
