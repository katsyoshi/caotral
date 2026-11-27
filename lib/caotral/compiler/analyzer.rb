require_relative "context"
require_relative "error"

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
        return unless ast_node?(node)
        type = node.type
        variables, args, body = node.children
        case type
        when :CLASS
          name = variables.children.last
          return if @context.classes[name] # skip dupricate class definition
          errors = invalid_class_definitions(name, args, body)
          unless errors.empty?
            raise Compiler::Error, "unsupported class definitions!!: #{errors.join(",")}"
          end
          klass = Caotral::Compiler::Context::Class.new(name:, body:)
          @context.register_class(klass)
          register_classes_variables_and_methods(body, name)
          return
        when :SCOPE
          variables.each { |v| @context.register_local_variable(v) }
        when :DEFN
          function = Caotral::Compiler::Context::Function.new(**analyze_function_scope(node))
          if classname
            klass = @context.classes[classname]
            klass.functions[function.name] = function
            return
          else
            @context.discover_method(variables)
            @context.register_function(function)
          end
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
        return false unless ast_node?(node)

        case node&.type
        when :BLOCK, :BEGIN
          node.children.any? { |n| main?(n) }
        when :CLASS, :DEFN
          false
        else
          true
        end
      end

      def invalid_class_definitions(name, args, child)
        errors = []
        errors << "#{name} has super #{args.children.first} class" if inheritanced?(args)
        errors << "#{name} has inner classes" if inner_classes?(child)
        errors
      end

      def inner_classes?(node)
        return false unless ast_node?(node)
        case node&.type
        when :CLASS
          true
        else
          node.children.any? { |n| inner_classes?(n) }
        end
      end
      def inheritanced?(node)
        return false unless ast_node?(node)

        !node.children.last.nil?
      end

      def analyze_function_scope(node)
        name, function_scope = node.children
        locals, args, body = function_scope.children
        parameter_count = args.children.first
        parameters = locals.take(parameter_count)
        locals = locals.drop(parameter_count)
        { name:, parameters:, locals:, body: }
      end

      def ast_node?(node) = node.kind_of?(RubyVM::AbstractSyntaxTree::Node)
    end
  end
end
