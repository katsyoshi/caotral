class Caotral::Linker::ELF::Sections
  include Enumerable

  def initialize = @sections = []
  def each(&block) = @sections.each(&block)
  def add(section) = @sections << section
  alias << add
  def size = @sections.size
  alias length size
  def empty? = @sections.empty?
  def count(&block)
    return @sections.count(&block) if block_given?
    @sections.size
  end
  
  def [](index)
    case index
    when Integer
      @sections[index]
    when String, Symbol
      index_string = index.to_s
      index_string.unshift(".") unless index_string.start_with?(".")
      @sections.find { it.section_name == index_string }
    else
      raise ArgumentError, "Invalid index type: #{index.class}"
    end
  end
end
