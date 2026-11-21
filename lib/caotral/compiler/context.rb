require_relative "context/class"
require_relative "context/function"
require_relative "context/variables"

module Caotral
  class Compiler
    class Context
      attr_reader :discovered_methods, :label_sequence, :entry, :functions, :classes
      def initialize
        @label_sequence = 0
        @entry_emitted = false
        @emitted_methods = Set[]
        @emitted_classes = Set[]
        @discovered_methods = Set[]
        @entry = nil
        @variables = Caotral::Compiler::Context::Variables.new
        @functions = {}
        @classes = {}
      end

      def entry_emitted? = @entry_emitted
      def mark_entry_emitted = @entry_emitted = true
      def mark_method_emitted(name) = @emitted_methods << name
      def mark_class_emitted(name) = @emitted_classes << name
      def discover_method(name) = @discovered_methods << name
      def discover_class(name) = @discovered_classes << name
      def register_local_variable(name) = @variables.register_local(name)
      def all_methods_emitted? = @discovered_methods == @emitted_methods
      def increment_label_sequence = @label_sequence += 1
      def local_variables = @variables.locals
      def register_entry(function) = @entry = function
      def register_function(function) = @functions[function.name] = function
      def register_class(klass) = @classes[klass.name] = klass
    end
  end
end
