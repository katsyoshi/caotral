class Caotral::Compiler
  module HIR
    class Node
      attr_reader :type, :children

      def initialize(type, children = {})
        @type = type
        @children = children
      end

      def [](key) = @children[key]
    end
  end
end
