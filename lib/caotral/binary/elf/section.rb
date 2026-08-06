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
          if Array === @body
            bytes = @body.flatten
            return bytes.pack("C*") if bytes.all?(Integer)
            return @body.each_with_object(StringIO.new) { |b, io| io.write(b.build) }.string
          end
          return @body if @body.is_a?(String)
          "".b
        end

        def layout!(offset:)
          size = build.bytesize
          align = [@header.addralign.to_i, 1].max
          offset = (offset + align - 1) / align * align
          @header.set!(offset:, size:)

          offset + size
        end
      end
    end
  end
end
