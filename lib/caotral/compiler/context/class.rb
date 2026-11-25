require_relative "function"
require_relative "variables"

module Caotral
  class Compiler
    class Context
      class Class
        attr_reader :name, :body, :functions
        def initialize(name:, body:)
          @name = name
          @body = body
          @functions = {}
        end
      end
    end
  end
end
