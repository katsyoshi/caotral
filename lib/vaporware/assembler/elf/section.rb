require_relative "section/text"
require_relative "section/bss"
require_relative "section/data"
require_relative "section/note"
require_relative "section/null"
require_relative "section/symtab"
require_relative "section/strtab"
require_relative "section/shstrtab"
require_relative "section_header"

class Vaporware::Assembler::ELF::Section
  attr_reader :header, :body, :name, :section_name
  def initialize(type:, options: {})
    type_string = type.to_s.capitalize
    type_string = type_string.upcase if type_string == "Bss"
    @section_name = type_string.downcase
    @name = section_name == "null" ? "" : "\0.#{section_name}" 
    @header = Vaporware::Assembler::ELF::SectionHeader.new.send("#{@section_name}!")
    @body = Module.const_get("Vaporware::Assembler::ELF::Section::#{type_string}").new(**options)
  end

  def name=(name)
    @name = name
  end
end
