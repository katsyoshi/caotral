# frozen_string_literal: true

require_relative "vaporware/version"
require "parser/current"

module Vaporware
  class Error < StandardError; end
  # Your code goes here...
  class Compiler
    attr_reader :ast, :_precompile, :debug
    def self.compile(source, dest: "tmp.s", debug: false)
      s = new(source, _precompile: dest, debug:)
      s.compile
    end

    def initialize(source, _precompile: "tmp.s", debug: false)
      @_precompile, @debug, @var = _precompile, debug, []
      @ast = Parser::CurrentRuby.parse(File.read(File.expand_path(source)))
    end

    def compile
      puts ast if debug
      output = File.open(_precompile, "w")
      output.puts ".intel_syntax noprefix"
      output.puts ".globl main"
      output.puts "main:"
      output.puts "  push rbp"
      output.puts "  mov rbp, rsp"
      output.puts "  sub rsp, 208"
      gen(ast, output)
      output.puts "  mov rsp, rbp"
      output.puts "  pop rbp"
      output.puts "  ret"
      output.close
      call_compiler
    end

    private

    def call_compiler(output = _precompile, compiler = "gcc")
      base_name = File.basename(output, ".*")
      IO.popen([compiler, "-O0", "-o", base_name, output]).close
      File.delete(output) unless debug
    end

    def gen(node, output)
      center = case node.type
      when :int
        output.puts "  push #{node.children.last}"
        return
      when :begin
        gen(node.children.first, output)
        :bigin
      when :send
        children = node.children
        left = children[0]
        right = children[2]
        gen(left, output)
        gen(right, output)

        output.puts "  pop rdi"
        output.puts "  pop rax"
        children[1]
      end

      case center
      when :+
        output.puts "  add rax, rdi"
      when :-
        output.puts "  sub rax, rdi"
      when :*
        output.puts "  imul rax, rdi"
      when :/
        output.puts "  cqo"
        output.puts "  idiv rdi"
      end
      output.puts "   push rax" unless node.type == :begin
    end
  end
end
