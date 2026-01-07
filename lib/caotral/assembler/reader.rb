require "set"

require "caotral/binary/elf"

module Caotral
  class Assembler
    class Reader
      def initialize(input:, debug: false)
        @input, @debug = input, debug
        @labels = Set.new
      end

      def read
        File.open(@input, "r") do |reader|
          reader.each_line do |line|
            if /^(?<label>[_A-Za-z.]\w*):/ =~ line
              @labels.add(label.to_sym)
              next
            end
          end
        end
        @labels
      end
    end
  end
end
