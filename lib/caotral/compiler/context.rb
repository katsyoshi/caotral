require_relative "context/function"
require_relative "context/variables"

module Caotral
  class Compiler
    class Context
      attr_reader :discovered_methods, :label_sequence
      def initialize
        @label_sequence = 0
        @entry_emitted = false
        @emitted_methods = Set[]
        @discovered_methods = Set[]
        @variables = Caotral::Compiler::Context::Variables.new
      end

      def entry_emitted? = @entry_emitted
      def mark_entry_emitted = @entry_emitted = true
      def mark_method_emitted(name) = @emitted_methods << name
      def discover_method(name) = @discovered_methods << name
      def register_local_variable(name) = @variables.register_local(name)
      def all_methods_emitted? = @discovered_methods == @emitted_methods
      def increment_label_sequence = @label_sequence += 1
      def local_variables = @variables.locals
    end
  end
end
