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

        def build
          return @body.build if @body.respond_to?(:build)
          return @body.each_with_object(StringIO.new) { |b, io| io.write(b.build) }.string if @body.is_a?(Array)
          return @body if @body.is_a?(String)
          "".b
        end
      end
    end
  end
end
