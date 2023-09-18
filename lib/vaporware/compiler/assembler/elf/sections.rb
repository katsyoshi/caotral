require_relative "section"

class Vaporware::Compiler::Assembler::ELF::Sections
  attr_reader %i|null text data bss note symtab strtab shsymtab|
  def initialize
    @null, @text, @data, @bss, @note, @symtab, @strtab, @shsymtab = %i|null text data bss note symtab strtab shsymtab|.map { |cn| Section.new(type: cn) }
  end
end
