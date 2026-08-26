module Caotral
  class Compiler
    class Emitter
      INDENT = " " * 2
      def initialize(io) = @io = io

      def instruction(operation, *operands)
        ops = operands.empty? ? "" : " #{operands.join(", ")}"
        @io.puts("#{INDENT}#{operation}#{ops}")
      end
      def label(name) = @io.puts("#{name}:")
      def directive(row) = @io.puts(row)
      def close = @io.close
    end
  end
end
