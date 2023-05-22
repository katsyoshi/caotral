# frozen_string_literal: true

module Vaporware
  class Compiler::Assemble
    attr_reader :input, :output
    def self.compile!(input, output = File.basename(input, ".*")) = new(input, output).compile

    def initialize(input, output = File.basename(input, ".*"))
      @input, @output = input, output
      @target_file = File.open(output, "wb")
    end

    def compile(compile_options = [])
      self
    end
  end
end
