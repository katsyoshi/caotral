require "caotral/binary/elf"

module Caotral
  class Assembler
    class Reader
      attr_reader :instructions
      def initialize(input:, debug: false)
        @input, @debug = input, debug
        @instructions = Hash.new { |h, k| h[k] = [] }
      end

      def read
        File.open(@input, "r") do |reader|
          current_label = nil
          reader.each_line do |line|
            if /^(?<label>[_A-Za-z.]\w*):/ =~ line
              current_label = label
              next
            end
            next if current_label.nil?

            @instructions[current_label] << line
          end
        end
        @instructions
      end
    end
  end
end
