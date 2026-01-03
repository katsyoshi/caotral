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
      @sections.find { it.section_name == prepend_dot(index) }
    else
      raise ArgumentError, "Invalid index type: #{index.class}"
    end
  end

  def index(name)
    name = prepend_dot(name)
    @sections.each_with_index do |section, idx|
      return idx if section.section_name == name
    end
  end
  private def prepend_dot(name)
    str = name.to_s
    str.start_with?(".") ? str : ".#{str}"
  end
end
