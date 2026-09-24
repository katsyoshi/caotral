class Caotral::Compiler
  module HIR
    def self.build!(ast) = Caotral::Compiler::HIR::Builder.build!(ast)
  end
end
