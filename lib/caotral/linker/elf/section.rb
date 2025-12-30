class Caotral::Linker::ELF::Section
  attr_accessor :name, :header
  attr_reader :section_name, :body
  def initialize(type:, options: {})
    type_string = type.to_s.capitalize
    type_string = type_string.upcase if type_string == "Bss"
    # section_name is extra information about section type
    @section_name = type_string.downcase
    # name is used in section header string table in elf file
    @name = section_name == "null" ? "" : "\0.#{section_name}"
    @header, @body = nil, nil
  end
end
