# frozen_string_literal: true

require_relative "vaporware/version"
require "parser/current"

module Vaporware
  class Error < StandardError; end
  # Your code goes here...
  class Compiler
    attr_reader :ast, :_precompile, :debug, :seq, :var
    def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"])
      s = new(source, _precompile: dest + ".s", debug:)
      s.compile(compiler:, compiler_options:)
    end

    def initialize(source, _precompile: "tmp.s", debug: false)
      @_precompile, @debug, @var, @seq = _precompile, debug, Set.new, 0
      src = File.read(File.expand_path(source))
      @ast = Parser::CurrentRuby.parse(src)
    end

    def compile(compiler: "gcc", compiler_options: ["-O0"])
      puts ast if debug

      register_var_and_method(ast)

      output = File.open(_precompile, "w")
      # prologue
      output.puts ".intel_syntax noprefix"
      output.puts ".globl main"
      output.puts "main:"
      output.puts "  push rbp"
      output.puts "  mov rbp, rsp"
      output.puts "  sub rsp, #{var.size * 8}"
      gen(ast, output)
      # epilogue
      output.puts "  mov rsp, rbp"
      output.puts "  pop rbp"
      output.puts "  ret"
      output.close
      call_compiler(compiler:, compiler_options:)
    end

    private

    def register_var_and_method(node)
      node.children.each do |child|
        next unless child.kind_of?(Parser::AST::Node)
        name, _ = child.children
        name = "#{child.type == :lvasgn ? :lvar : child.type}_#{name}".to_sym
        if variable_or_method?(child)
          @var << name
          next
        end
        register_var_and_method(child)
      end
    end

    def variable_or_method?(node) = [:def, :lvasgn].include?(node.type)

    def call_compiler(output: _precompile, compiler: "gcc", compiler_options: ["-O0"])
      base_name = File.basename(output, ".*")
      compile_commands = [compiler, *compiler_options, "-o", base_name, output].compact
      IO.popen(compile_commands).close

      puts File.read(output) if debug
      nil
    end

    def gen_prologue(node, output) = nil
    def gen_method(node, output) = nil

    def gen_comp(op, output)
      output.puts "  cmp rax, rdi"
      output.puts "  #{op} al"
      output.puts "  movzb rax, al"
      output.puts "  push rax"
      nil
    end

    def gen_lvar(var, output)
      output.puts "  mov rax, rbp"
      output.puts "  sub rax, #{lvar_offset(var) * 8}"
      output.puts "  push rax"
      nil
    end

    def lvar_offset(var)
      return @var.size if var.nil?
      @var.find_index(var).to_i + 1
    end

    def gen_ret(output)
      output.puts "  pop rax"
      output.puts "  mov rsp, rbp"
      output.puts "  pop rbp"
      output.puts "  ret"
    end

    def gen(node, output)
      center = case node.type
      when :int
        output.puts "  push #{node.children.last}"
        return
      when :begin
        node.children.each do |child|
          gen(child, output)
        end
        return
      when :lvar
        name = "lvar_#{node.children.last}".to_sym
        gen_lvar(name, output)
        # lvar
        output.puts "  pop rax"
        output.puts "  mov rax, [rax]"
        output.puts "  push rax"
        return
      when :lvasgn
        left, right = node.children

        # rvar
        name = "lvar_#{left}".to_sym
        gen_lvar(name, output)
        gen(right, output)

        output.puts "  pop rdi"
        output.puts "  pop rax"
        output.puts "  mov [rax], rdi"
        output.puts "  push rdi"
        output.puts "  pop rax"
        return
      when :if
        cond, tblock, fblock = node.children
        gen(cond, output)
        output.puts "  pop rax"
        output.puts "  push rax"
        output.puts "  cmp rax, 0"
        if fblock
          output.puts "  je .Lelse#{seq}"
          gen(tblock, output)
          gen_ret(output)
          output.puts "  jmp .Lend#{seq}"
          output.puts ".Lelse#{seq}:"
          gen(fblock, output)
          gen_ret(output)
          output.puts ".Lend#{seq}:"
        else
          output.puts "  je .Lend#{seq}"
          gen(tblock, output)
          gen_ret(output)
          output.puts ".Lend#{seq}:"
        end
        @seq += 1
        return
      when :while
        cond, tblock = node.children
        output.puts ".Lbegin#{seq}:"
        gen(cond, output)
        output.puts "  pop rax"
        output.puts "  push rax"
        output.puts "  cmp rax, 0"
        output.puts "  je .Lend#{seq}"
        gen(tblock, output)
        output.puts "  jmp .Lbegin#{seq}"
        output.puts ".Lend#{seq}:"
        @seq += 1
        return
      when :send
        left, center, right = node.children
        gen(left, output) unless left.nil?
        gen(right, output)

        output.puts "  pop rdi"
        output.puts "  pop rax"
        center
      end

      case center
      when :+
        output.puts "  add rax, rdi"
        output.puts "  push rax"
      when :-
        output.puts "  sub rax, rdi"
        output.puts "  push rax"
      when :*
        output.puts "  imul rax, rdi"
        output.puts "  push rax"
      when :/
        output.puts "  cqo"
        output.puts "  idiv rdi"
        output.puts "  push rax"
      when :==
        gen_comp("sete", output)
      when :!=
        gen_comp("setne", output)
      when :<
        gen_comp("setl", output)
      when :<=
        gen_comp("setle", output)
      end
    end
  end
end
