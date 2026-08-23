module Caotral
  module Binary
    class Archive
      class Member
        attr_reader :elf, :offset, :name

        def initialize(name:, body:, offset:)
          @name = name
          @body = StringIO.new(body)
          @offset = offset
        end

        def read
          return self if @elf
          reader = Caotral::Binary::ELF::Reader.new(input: @body)
          reader.read
          @elf = reader.context
          @body = nil
          self
        end
      end
    end
  end
end
