# frozen_string_literal: true

module Vaporware
  class Compiler
    class Generator
      attr_accessor :main
      attr_reader :ast, :_precompile, :debug, :seq, :defined_variables, :doned, :shared, :defined_methods
      def initialize(source, _precompile:, debug:, shared:)
        @_precompile, @debug, @shared = _precompile, debug, shared
        @doned, @defined_methods, @defined_variables = Set.new, Set.new, Set.new
        @seq, @main = 0, false
        src = File.read(File.expand_path(source))
        @ast = Parser::CurrentRuby.parse(src)
      end

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

      def epilogue(output)
        output.puts "  mov rsp, rbp"
        output.puts "  pop rbp"
        output.puts "  ret"
      end

      def prologue_methods(output)
        defined_methods.each do |name|
          output.puts ".globl #{name}"
          output.puts ".type #{name}, @function" if shared
        end
        nil
      end

      def define_method_prologue(node, output)
        output.puts "  push rbp"
        output.puts "  mov rbp, rsp"
        output.puts "  sub rsp, #{lvar_offset(nil) * 8}"
        _name, args, _block = node.children
        args.children.each_with_index do |_, i|
          output.puts "  mov [rbp-#{(i + 1) * 8}], #{REGISTER[i]}"
        end
        nil
      end

      def method(method, node, output)
        output.puts "#{method}:"
        define_method_prologue(node, output)
        node.children.each do |child|
          next unless child.kind_of?(Parser::AST::Node)
          build(child, output, true)
        end
        ret(output)
        @doned << method
        nil
      end

      def args(node, output)
        node.children.each do |child|
          name = "arg_#{child.children.first}".to_sym
          lvar(name, output)
          output.puts "  pop rax"
          output.puts "  mov rax, [rax]"
          output.puts "  push rax"
        end
      end

      def call_method(node, output, method_tree)
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
          build(arg, output, method_tree)
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

      def comp(op, output)
        output.puts "  cmp rax, rdi"
        output.puts "  #{op} al"
        output.puts "  movzb rax, al"
        output.puts "  push rax"
        nil
      end

      def lvar(var, output)
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

      def ret(output)
        output.puts "  pop rax"
        output.puts "  mov rsp, rbp"
        output.puts "  pop rbp"
        output.puts "  ret"
      end

      def build(node, output, method_tree = false)
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
            build(child, output)
          end
          return
        when :def
          name, _ = node.children
          method(name, node, output)
          return
        when :args
          args(node, output)
          return
        when :lvar
          return if method_tree
          name = "lvar_#{node.children.last}".to_sym
          lvar(name, output)
          # lvar
          output.puts "  pop rax"
          output.puts "  mov rax, [rax]"
          output.puts "  push rax"
          return
        when :lvasgn
          left, right = node.children

          # rvar
          name = "lvar_#{left}".to_sym
          lvar(name, output)
          build(right, output, method_tree)

          output.puts "  pop rdi"
          output.puts "  pop rax"
          output.puts "  mov [rax], rdi"
          output.puts "  push rdi"
          output.puts "  pop rax"
          return
        when :if
          cond, tblock, fblock = node.children
          build(cond, output)
          output.puts "  pop rax"
          output.puts "  push rax"
          output.puts "  cmp rax, 0"
          if fblock
            output.puts "  je .Lelse#{seq}"
            build(tblock, output, method_tree)
            ret(output)
            output.puts "  jmp .Lend#{seq}"
            output.puts ".Lelse#{seq}:"
            build(fblock, output, method_tree)
            ret(output)
            output.puts ".Lend#{seq}:"
          else
            output.puts "  je .Lend#{seq}"
            build(tblock, output, method_tree)
            ret(output)
            output.puts ".Lend#{seq}:"
          end
          @seq += 1
          return
        when :while
          cond, tblock = node.children
          output.puts ".Lbegin#{seq}:"
          build(cond, output, method_tree)
          output.puts "  pop rax"
          output.puts "  push rax"
          output.puts "  cmp rax, 0"
          output.puts "  je .Lend#{seq}"
          build(tblock, output, method_tree)
          output.puts "  jmp .Lbegin#{seq}"
          output.puts ".Lend#{seq}:"
          @seq += 1
          return
        when :send
          left, center, right = node.children
          build(left, output, method_tree) unless left.nil?
          if left.nil?
            call_method(node, output, method_tree)
          else
            build(right, output, method_tree)
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
          comp("sete", output)
        when :!=
          comp("setne", output)
        when :<
          comp("setl", output)
        when :<=
          comp("setle", output)
        end
      end
    end
  end
end
