module Caotral
  module Binary
    class ELF
      module SymbolTable
        def find_defined_symbol(symbol_name) = body.find { |sym| sym.name_string == symbol_name && sym.shndx != 0 }
      end
    end
  end
end
