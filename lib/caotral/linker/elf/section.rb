class Caotral::Linker
  class ELF
    class Section
      attr_reader :name, :section_name
      attr_accessor :header, :body
      def initialize(type:, section_name: nil, options: {})
        type_string = type.to_s.capitalize
        type_string = type_string.upcase if type_string == "Bss"
        @section_name = (section_name.nil? ? type_string : section_name).to_s.downcase
        # name is used in section header string table in elf file
        @name = @section_name == "null" ? "" : "\0.#{@section_name}"
        @header, @body = nil, nil
      end
    end
  end
end
