require_relative "section"

class Vaporware::Compiler::Assembler::ELF::Sections
  ATTRIBUTES = %i|null text data bss note symtab strtab shstrtab|
  attr_reader *ATTRIBUTES
  def initialize
    @null = Section.new(type: :null)
    @text = Section.new(type: :text)
    @data = Section.new(type: :data)
    @bss = Section.new(type: :bss)
    @note = Section.new(type: :note)
    @symtab = Section.new(type: :symtab)
    @strtab = Section.new(type: :strtab)
    @shstrtab = Section.new(type: :shstrtab)
  end

  def each(&block)
    ATTRIBUTES.each do |t|
      yield t
    end
  end
end
