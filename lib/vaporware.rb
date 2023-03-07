# frozen_string_literal: true

require_relative "vaporware/version"
require "parser/current"

module Vaporware
  class Error < StandardError; end
  # Your code goes here...
  class Compiler
    attr_reader :ast
    def self.compile(source)
      s = new(source)
      s.compile
    end

    def initialize(source) = @ast = Parser::CurrentRuby.parse(File.read(File.expand_path(source)))

    def compile
      STDERR.puts ast
      puts ".intel_syntax noprefix"
      puts ".globl main"
      puts "main:"
      gen(ast)
      puts "   pop rax"
      puts "   ret"
    end

    def gen(node)
      center = case node.type
      when :int
        puts "   push #{node.children.last}"
        return
      when :begin
        gen(node.children.first)
        :bigin
      when :send
        children = node.children
        left = children[0]
        right = children[2]
        gen(left)
        gen(right)

        puts "   pop rdi"
        puts "   pop rax"
        children[1]
      end

      case center
      when :+
        puts "   add rax, rdi"
      when :-
        puts "   sub rax, rdi"
      when :*
        puts "   imul rax, rdi"
      when :/
        puts "   cqo"
        puts "   idiv rdi"
      end
      puts "   push rax" unless center == :bigin
    end
  end
end
