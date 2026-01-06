module Caotral
  class Binary
    class ELF
      class Section
        attr_reader :header, :body, :section_name
        def initialize(header:, body:, section_name:)
          @header = header
          @body = body
          @section_name = section_name
        end
      end
    end
  end
end
