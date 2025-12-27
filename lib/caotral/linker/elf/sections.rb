class Caotral::Linker::ELF::Sections
  include Enumerable

  def initialize = @sections = []
  def each(&block) = @sections.each(&block)
  def add(section) = @sections << section
  alias << add
  def [](index)
    case index
    when Integer
      @sections[index]
    when String, Symbol
      @sections.find { _1.section_name.to_s == index.to_s }
    else
      raise ArgumentError, "Invalid index type: #{index.class}"
    end
  end
end
