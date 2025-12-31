class Caotral::Linker
  class ELF
    class Section
      attr_accessor :header, :body, :section_name
      def initialize(type:, section_name: nil, options: {})
        type_string = type.to_s.capitalize
        type_string = type_string.upcase if type_string == "Bss"
        @section_name = (section_name.nil? ? type_string : section_name).to_s.downcase
        @header, @body = nil, nil
      end

      def name = @section_name == "null" ? "" : "\0.#{@section_name}"
    end
  end
end
