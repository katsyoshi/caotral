require_relative "section"

class Vaporware::Assembler::ELF::Sections
  ATTRIBUTES = %i|null text data bss note symtab strtab shstrtab|
  attr_reader *ATTRIBUTES

  def initialize
    @null = Vaporware::Assembler::ELF::Section.new(type: :null)
    @text = Vaporware::Assembler::ELF::Section.new(type: :text)
    @data = Vaporware::Assembler::ELF::Section.new(type: :data)
    @bss = Vaporware::Assembler::ELF::Section.new(type: :bss)
    @note = Vaporware::Assembler::ELF::Section.new(type: :note, options: {type: :gnu})
    @symtab = Vaporware::Assembler::ELF::Section.new(type: :symtab)
    @strtab = Vaporware::Assembler::ELF::Section.new(type: :strtab)
    @shstrtab = Vaporware::Assembler::ELF::Section.new(type: :shstrtab)
  end

  def each(&block) = ATTRIBUTES.each { |t|  yield send(t) }
end
