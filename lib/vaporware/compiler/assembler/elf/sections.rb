require_relative "section"

class Vaporware::Compiler::Assembler::ELF::Sections
  ATTRIBUTES = %i|null text data bss note symtab strtab shstrtab|
  attr_reader *ATTRIBUTES
  def initialize
    @null = Vaporware::Compiler::Assembler::ELF::Section.new(type: :null)
    @text = Vaporware::Compiler::Assembler::ELF::Section.new(type: :text)
    @data = Vaporware::Compiler::Assembler::ELF::Section.new(type: :data)
    @bss = Vaporware::Compiler::Assembler::ELF::Section.new(type: :bss)
    @note = Vaporware::Compiler::Assembler::ELF::Section.new(type: :note)
    @symtab = Vaporware::Compiler::Assembler::ELF::Section.new(type: :symtab)
    @strtab = Vaporware::Compiler::Assembler::ELF::Section.new(type: :strtab)
    @shstrtab = Vaporware::Compiler::Assembler::ELF::Section.new(type: :shstrtab)
  end

  def each(&block)
    (ATTRIBUTES - [:shstrtab]).each do |t|
      yield send(t)
    end
  end
end
