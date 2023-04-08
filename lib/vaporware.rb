# frozen_string_literal: true

require_relative "vaporware/version"
require "parser/current"

module Vaporware
  class Error < StandardError; end
  # Your code goes here...
  class Compiler
    MEM_ADDR = 26 * 8
    attr_reader :ast, :_precompile, :debug
    def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"])
      s = new(source, _precompile: dest + ".s", debug:)
      s.compile(compiler:, compiler_options:)
    end

    def initialize(source, _precompile: "tmp.s", debug: false)
      @_precompile, @debug, @var = _precompile, debug, []
      @ast = Parser::CurrentRuby.parse(File.read(File.expand_path(source)))
      @seq = 0
    end

    def compile(compiler: "gcc", compiler_options: ["-O0"])
      puts ast if debug
      output = File.open(_precompile, "w")
      output.puts "  .intel_syntax noprefix"
      output.puts "  .globl main"
      output.puts "main:"
      output.puts "  push rbp"
      output.puts "  mov rbp, rsp"
      output.puts "  sub rsp, #{MEM_ADDR}"
      gen(ast, output)
      output.puts "  mov rsp, rbp"
      output.puts "  pop rbp"
      output.puts "  ret"
      output.close
      call_compiler(compiler:, compiler_options:)
    end

    private

    def call_compiler(output: _precompile, compiler: "gcc", compiler_options: ["-O0"])
      base_name = File.basename(output, ".*")
      compile_commands = [compiler, *compiler_options, "-o", base_name, output].compact
      IO.popen(compile_commands).close
      File.delete(output) unless debug
    end

    def gen_lvar(var, output)
      output.puts "  mov rax, rbp"
      output.puts "  sub rax, #{MEM_ADDR - lvar_offset(var) * 8}"
      output.puts "  push rax"
    end

    def lvar_offset(var)
      @var.index(var).then do |index|
        unless index
          @var << var
          index = @var.size - 1
        end
        index
      end
    end

    def gen(node, output)
      center = case node.type
      when :int
        output.puts "  push #{node.children.last}"
        return
      when :begin
        node.children.each do |child|
          gen(child, output)
          output.puts "  pop rax"
        end
      when :lvar
        gen_lvar(node.children.last, output)
        # lvar
        output.puts "  pop rax"
        output.puts "  mov rax, [rax]"
        output.puts "  push rax"
        return
      when :lvasgn
        left, right = node.children

        # rvar
        gen_lvar(left, output)
        gen(right, output)

        output.puts "  pop rdi"
        output.puts "  pop rax"
        output.puts "  mov [rax], rdi"
        output.puts "  push rdi"
        output.puts "  pop rax"
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
      output.puts "  push rax"
    end
  end
end
