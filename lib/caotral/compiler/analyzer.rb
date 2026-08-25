require_relative "context"

module Caotral
  class Compiler
    class Analyzer
      def self.analyze(ast, context = Caotral::Compiler::Context.new)
        new(ast, context).analyze
      end

      def initialize(ast, context)
        @ast = ast
        @context = context
      end

      def analyze
        register_variables_and_methods(@ast)
        @context
      end

      private
      def register_variables_and_methods(node)
        return unless node.kind_of?(RubyVM::AbstractSyntaxTree::Node)
        type = node.type
        variables, *_ = node.children
        case type
        when :SCOPE
          variables.each { |v| @context.register_local_variable(v) }
        when :DEFN
          @context.discover_method(variables)
        end
        node.children.each { |n| register_variables_and_methods(n) }
        nil
      end
    end
  end
end
