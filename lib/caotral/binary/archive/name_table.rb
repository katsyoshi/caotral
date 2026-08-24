module Caotral
  module Binary
    class Archive
      class NameTable
        attr_reader :names

        def initialize(body:)
          @body = StringIO.new(body)
          @names = []
          @name_offsets = {}
        end

        def parse!
          until @body.eof?
            offset = @body.pos
            entry = @body.gets("/\n")
            break if entry == "\n"
            name = entry.delete_suffix("/\n")
            @names << name
            @name_offsets[offset] = name
          end
          self
        end

        def resolve(offset)
          @name_offsets.fetch(offset) do
            raise Caotral::Binary::Archive::Error, "invalid name offset: #{offset}"
          end
        end
      end
    end
  end
end
