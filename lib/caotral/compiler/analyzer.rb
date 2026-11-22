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
        @execution = false
      end

      def analyze
        register_entry(@ast) if main?(@ast.children.last)
        register_classes_variables_and_methods(@ast)
        @context
      end

      private
      def register_classes_variables_and_methods(node, classname = nil)
        return unless node.kind_of?(RubyVM::AbstractSyntaxTree::Node)
        type = node.type
        variables, args, body = node.children
        case type
        when :CLASS
          name = variables.children.last
          return if @context.classes[name] # skip dupricate class definition
          klass = Caotral::Compiler::Context::Class.new(name:, body:)
          @context.register_class(klass)
          return
        when :SCOPE
          variables.each { |v| @context.register_local_variable(v) }
        when :DEFN
          @context.discover_method(variables)
          function = Caotral::Compiler::Context::Function.new(**analyze_function_scope(node))
          @context.register_function(function)
        end
        node.children.each { |n| register_classes_variables_and_methods(n, classname) }
        nil
      end

      def register_entry(scope)
        locals, _args, body = scope.children
        entry = Caotral::Compiler::Context::Function.new(name: nil, locals:, body:)
        @context.register_entry(entry)
      end

      def main?(node)
        case node&.type
        when nil
          false
        when :BLOCK, :BEGIN
          node.children.any? { |n| main?(n) }
        when :CLASS, :DEFN
          false
        else
          true
        end
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
