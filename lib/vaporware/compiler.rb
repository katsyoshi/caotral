# frozen_string_literal: true

require "parser/current"

module Vaporware
  # Your code goes here...
  class Compiler
    REGISTER = %w(r9 r8 rcx rdx rsi rdi).reverse
    attr_reader :ast, :_precompile, :debug, :seq, :defined_variables, :doned, :main, :shared, :defined_methods
    def self.compile(source, compiler: "gcc", dest: "tmp", debug: false, compiler_options: ["-O0"], shared: false)
      _precompile = "#{dest}.s"
      s = new(source, _precompile: _precompile, debug:, shared:)
      s.compile(compiler:, compiler_options:)
    end

    def initialize(source, _precompile: "tmp.s", debug: false, shared: false)
      @_precompile, @debug, @seq, @shared = _precompile, debug, 0, shared
      @defined_methods = Set.new
      @defined_variables = Set.new
      @doned = Set.new
      src = File.read(File.expand_path(source))
      @ast = Parser::CurrentRuby.parse(src)
      @main = false
    end

    def compile(compiler: "gcc", compiler_options: ["-O0"])
      puts ast if debug

      register_var_and_method(ast)

      output = File.open(_precompile, "w")
      # prologue
      output.puts ".intel_syntax noprefix"
      if defined_methods.empty?
        @main = true
        output.puts ".globl main"
        output.puts "main:"
        output.puts "  push rbp"
        output.puts "  mov rbp, rsp"
        output.puts "  sub rsp, #{defined_variables.size * 8}"
        gen(ast, output)
        # epilogue
        gen_epilogue(output)
      else
        gen_prologue_methods(output)
        output.puts ".globl main" unless shared
        gen(ast, output)
        # epilogue
        gen_epilogue(output)
      end
      output.close
      compiler_options += compile_shared_option if shared
      call_compiler(compiler:, compiler_options:)
    end

    private

    def compile_shared_option = %w(-shared -fPIC)

    def register_var_and_method(node)
      return unless node.kind_of?(Parser::AST::Node)
      type = node.type
      if variable_or_method?(type)
        name, _ = node.children
        name = [:lvasgn, :arg].include?(type) ? "lvar_#{name}".to_sym : name
        type == :def ? @defined_methods << name : @defined_variables << name
      end
      node.children.each { |n| register_var_and_method(n) }
    end

    def already_build_methods? = defined_methods.sort == @doned.to_a.sort
    def variable_or_method?(type) = [:lvasgn, :arg, :def].include?(type)

    def call_compiler(output: _precompile, compiler: "gcc", compiler_options: ["-O0"], debug: false)
      base_name = File.basename(output, ".*")
      name = shared ? "lib#{base_name}.so" : base_name
      compile_commands = [compiler, *compiler_options, "-o", name, output].compact
      IO.popen(compile_commands).close

      puts File.read(output) if debug
      nil
    end

    def gen_epilogue(output)
      output.puts "  mov rsp, rbp"
      output.puts "  pop rbp"
      output.puts "  ret"
    end

    def gen_prologue_methods(output)
      defined_methods.each do |name|
        output.puts ".globl #{name}"
        output.puts ".type #{name}, @function" if shared
      end
      nil
    end

    def gen_define_method_prologue(node, output)
      output.puts "  push rbp"
      output.puts "  mov rbp, rsp"
      output.puts "  sub rsp, #{lvar_offset(nil) * 8}"
      _name, args, _block = node.children
      args.children.each_with_index do |_, i|
        output.puts "  mov [rbp-#{(i + 1) * 8}], #{REGISTER[i]}"
      end
      nil
    end

    def gen_method(method, node, output)
      output.puts "#{method}:"
      gen_define_method_prologue(node, output)
      node.children.each do |child|
        next unless child.kind_of?(Parser::AST::Node)
        gen(child, output, true)
      end
      gen_ret(output)
      @doned << method
      nil
    end

    def gen_args(node, output)
      node.children.each do |child|
        name = "arg_#{child.children.first}".to_sym
        gen_lvar(name, output)
        output.puts "  pop rax"
        output.puts "  mov rax, [rax]"
        output.puts "  push rax"
      end
    end

    def gen_call_method(node, output, method_tree)
      output.puts "  mov rax, rsp"
      output.puts "  mov rdi, 16"
      output.puts "  cqo"
      output.puts "  idiv rdi"
      output.puts "  mov rax, 0"
      output.puts "  cmp rdi, 0"
      output.puts "  jne .Lprecall#{seq}"
      output.puts "  push 0"
      output.puts "  mov rax, 1"
      output.puts ".Lprecall#{seq}:"
      output.puts "  push rax"
      _, name, *args = node.children
      args.each_with_index do |arg, i|
        gen(arg, output, method_tree)
        output.puts "  pop #{REGISTER[i]}"
      end

      output.puts "  call #{name}"
      output.puts "  pop rdi"
      output.puts "  cmp rdi, 0"
      output.puts "  je .Lpostcall#{seq}"
      output.puts "  pop rdi"
      output.puts ".Lpostcall#{seq}:"
      output.puts "  push rax"
      @seq += 1
      nil
    end

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
      return @defined_variables.size if var.nil?
      @defined_variables.find_index(var).then do |i|
        raise "unknown local variable...: #{var}" if i.nil?
        i + 1
      end
    end

    def gen_ret(output)
      output.puts "  pop rax"
      output.puts "  mov rsp, rbp"
      output.puts "  pop rbp"
      output.puts "  ret"
    end

    def gen(node, output, method_tree = false)
      return unless node.kind_of?(Parser::AST::Node)
      type = node.type
      center = case type
      when :int
        output.puts "  push #{node.children.last}"
        return
      when :begin
        node.children.each do |child|
          if already_build_methods? && !@main
            return if shared
            output.puts "main:"
            output.puts "  push rbp"
            output.puts "  mov rbp, rsp"
            output.puts "  sub rsp, 0"
            output.puts "  push rax"
            @main = true
          end
          gen(child, output)
        end
        return
      when :def
        name, _ = node.children
        gen_method(name, node, output)
        return
      when :args
        gen_args(node, output)
        return
      when :lvar
        return if method_tree
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
        gen(right, output, method_tree)

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
          gen(tblock, output, method_tree)
          gen_ret(output)
          output.puts "  jmp .Lend#{seq}"
          output.puts ".Lelse#{seq}:"
          gen(fblock, output, method_tree)
          gen_ret(output)
          output.puts ".Lend#{seq}:"
        else
          output.puts "  je .Lend#{seq}"
          gen(tblock, output, method_tree)
          gen_ret(output)
          output.puts ".Lend#{seq}:"
        end
        @seq += 1
        return
      when :while
        cond, tblock = node.children
        output.puts ".Lbegin#{seq}:"
        gen(cond, output, method_tree)
        output.puts "  pop rax"
        output.puts "  push rax"
        output.puts "  cmp rax, 0"
        output.puts "  je .Lend#{seq}"
        gen(tblock, output, method_tree)
        output.puts "  jmp .Lbegin#{seq}"
        output.puts ".Lend#{seq}:"
        @seq += 1
        return
      when :send
        left, center, right = node.children
        gen(left, output, method_tree) unless left.nil?
        if left.nil?
          gen_call_method(node, output, method_tree)
        else
          gen(right, output, method_tree)
          output.puts "  pop rdi"
        end
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
