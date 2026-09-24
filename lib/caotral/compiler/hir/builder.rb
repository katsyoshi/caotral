require_relative "handlers/scope"
require_relative "handlers/block"
require_relative "handlers/method_definition"
require_relative "handlers/call"
require_relative "node"

class Caotral::Compiler
  module HIR
    class Builder
      HANDLER = {
        SCOPE: Handlers::Scope,
        BLOCK: Handlers::Block,
        DEFN:  Handlers::MethodDefinition,
        CALL:  Handlers::Call,
      }.freeze

      def self.build!(ast) = new(ast).build!

      def initialize(ast) = @ast = ast

      def build! = process_node(@ast)

      private

      def process_node(node)
        return nil if node.nil?
        handler = HANDLER.fetch(node.type) { raise "unsupported node type" }
        result = handler.process(node)

        children = result.children.map do |slot, child|
          converted = if Array === child
                        child.map { |c| process_node(c) }
                      else
                        process_node(child)
                      end
          [slot, converted]
        end.to_h

        Node.new(result.type, result.hir.merge(children))
      end
    end
  end
end
