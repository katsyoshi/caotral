# frozen_string_literal: true

require_relative "vaporware/version"

module Vaporware
  class Error < StandardError; end
  # Your code goes here...
  class Compiler
    attr_reader :source, :ast
    def initialize(source = nil) = @source = source
    def self.compile(source) = new(source).compile
    end
  end
end
