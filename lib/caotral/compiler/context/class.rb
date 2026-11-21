require_relative "function"
require_relative "variables"

module Caotral
  class Compiler
    class Context
      class Class
        attr_reader :name, :body
        def initialize(name:, body:)
          @name = name
          @body = body
        end
      end
    end
  end
end
