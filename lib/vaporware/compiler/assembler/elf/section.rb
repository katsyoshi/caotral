require_relative "section/text"
require_relative "section/bss"
require_relative "section/data"
require_relative "section/note"
require_relative "section/null"
require_relative "section/symtab"
require_relative "section/strtab"
require_relative "section/shstrtab"
require_relative "section_header"

class Vaporware::Compiler::Assembler::ELF::Section
  attr_reader :header, :body, :name
  def initialize(type:, options: {})
    type_string = type.to_s.capitalize
    type_string = type_string.upcase if type_string == "Bss"
    section_name = type_string.downcase
    @name = "\0.#{section_name}\0"
    @header = Vaporware::Compiler::Assembler::ELF::SectionHeader.new.send("#{section_name}!")
    @body = Module.const_get("Vaporware::Compiler::Assembler::ELF::Section::#{type_string}").new(**options)
  end
end
