module Caotral
  class Compiler
    class Context
      class Variables
        attr_reader :locals
        def initialize = @locals = Set[]
        def register_local(name) = @locals.add?(name)
      end
    end
  end
end
