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
        register_entry(@ast)
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
          function = Caotral::Compiler::Context::Function.new(**analyze_function_scope(node))
          @context.register_function(function)
        end
        node.children.each { |n| register_variables_and_methods(n) }
        nil
      end

      def register_entry(scope)
        locals, _args, body = scope.children
        entry = Caotral::Compiler::Context::Function.new(name: nil, locals:, body:)
        @context.register_entry(entry)
      end

      def analyze_function_scope(node)
        name, function_scope = node.children
        locals, args, body = function_scope.children
        parameter_count = args.children.first
        parameters = locals.take(parameter_count)
        locals = locals.drop(parameter_count)
        { name:, parameters:, locals:, body: }
      end
    end
  end
end
