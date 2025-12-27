class Caotral::Linker::ELF
  attr_reader :sections, :header
  def initialize
    @sections = Caotral::Linker::ELF::Sections.new
    @header = Caotral::Linker::ELF::Header.new
  end
end
