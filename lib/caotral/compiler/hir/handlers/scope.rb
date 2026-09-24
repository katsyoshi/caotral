require_relative "node"

class Caotral::Compiler
  class HIR::Handlers::Scope
    attr_reader :node, :hir, :children
    def self.process(node) = new(node).process

    def initialize(node)
      @node = node
      locals, args, body = node.children
      @hir = { locals: }
      @children = { args:, body: }
    end

    def process = HIR::Result.new(:SCOPE, @hir, @children)
  end
end
