require_relative "variables"

module Caotral
  class Compiler
    class Context
      class Function
        attr_reader :name, :parameters, :body
        def initialize(name:, parameters: [], locals: [], body:)
          @name = name
          @parameters = parameters
          @variables = Caotral::Compiler::Context::Variables.new
          locals.each { |name| @variables.register_local(name) }
          @body = body
        end

        def locals = @variables.locals
        def variables = parameters + locals.to_a
      end
    end
  end
end
