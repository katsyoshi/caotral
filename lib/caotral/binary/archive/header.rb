module Caotral
  module Binary
    class Archive
      class Header
        attr_reader :name, :size, :fmsg
        def initialize(str)
          @name, size, @fmsg = str.unpack("A16x12x6x6x8A10a2")
          @size = Integer(size, 10)
        end

        def symbol_table? = @name == "/"
        def name_table? = @name == "//"
      end
    end
  end
end
