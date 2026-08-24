module Caotral
  module Binary
    class Archive
      class SymbolTable
        attr_reader :symbols

        Symbol = Data.define(:name, :offset)
        def initialize(body:)
          @body = StringIO.new(body)
          @symbols = []
        end

        def parse!
          count = @body.read(4).unpack1("N")

          offsets = count.times.map { @body.read(4).unpack1("N") }
          names = count.times.map do
            entry = @body.gets("\0")
            unless entry&.end_with?("\0")
              raise Caotral::Binary::Archive::Error, "invalid symbol table"
            end

            entry.delete_suffix("\0")
          end
          @symbols = names.zip(offsets).map { |name, offset| Symbol.new(name:, offset:) }
          self
        end

        def names = @symbols.map(&:name)
        def offset_of(name) = @symbols.find { |symbol| symbol.name == name }&.offset
      end
    end
  end
end
