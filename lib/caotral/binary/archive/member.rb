require_relative "header"

module Caotral
  module Binary
    class Archive
      class Member
        attr_reader :body, :header

        def initialize(bin)
          @header = Caotral::Binary::Archive::Header.new(bin.read(60))
          size = @header.size
          @body_bin = bin.read(@header.size)
          bin.read(1) if size.odd?
        end

        def read! = @body = ""
      end
    end
  end
end
