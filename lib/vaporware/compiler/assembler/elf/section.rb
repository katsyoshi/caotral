require_relative "section/text"
require_relative "section/bss"
require_relative "section/data"
require_relative "section/note"
require_relative "section/symtab"
require_relative "section/strtab"
require_relative "section/shsymtab"
require_relative "section/shstrtab"
require_relative "section_headers"

class Vaporware::Compiler::Assembler::ELF::Section
  def initialize(type:)
    type_string = type.to_s.capitalize
    type_string = type_string.upcase if type_string == "Bss"
    @header = Vaporware::Compiler::Assembler::ELF::SectionHeader.new.send("#{type_string.downcase}!")
    base = "Vaporware::Compiler::Assembler::ELF::Section"
    eval_string = type_string == "Null" ? "#{base}.new" : "#{base}::#{type_string}.new"
    @body = eval(eval_string)
  end
end
