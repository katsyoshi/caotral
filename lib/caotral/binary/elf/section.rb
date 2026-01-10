module Caotral
  module Binary
    class ELF
      class Section
        attr_accessor :body, :section_name
        attr_reader :header
        def initialize(header:, body:, section_name:)
          @header = header
          @body = body
          @section_name = section_name
        end
      end
    end
  end
end
