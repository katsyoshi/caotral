require_relative "section"

class Caotral::Assembler::ELF::Sections
  ATTRIBUTES = %i|null text data bss note symtab strtab shstrtab|
  attr_reader *ATTRIBUTES

  def initialize
    @null = Caotral::Assembler::ELF::Section.new(type: :null)
    @text = Caotral::Assembler::ELF::Section.new(type: :text)
    @data = Caotral::Assembler::ELF::Section.new(type: :data)
    @bss = Caotral::Assembler::ELF::Section.new(type: :bss)
    @note = Caotral::Assembler::ELF::Section.new(type: :note, options: {type: :gnu})
    @symtab = Caotral::Assembler::ELF::Section.new(type: :symtab)
    @strtab = Caotral::Assembler::ELF::Section.new(type: :strtab)
    @shstrtab = Caotral::Assembler::ELF::Section.new(type: :shstrtab)
  end

  def each(&block) = ATTRIBUTES.each { |t|  yield send(t) }
end
