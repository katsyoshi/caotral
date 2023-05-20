# frozen_string_literal: true

module Vaporware
  class Compiler
    class Generator
      REGISTER = %w(rdi rsi rdx rcx r8 r9)
      attr_accessor :main
      attr_reader :ast, :precompile, :debug, :seq, :defined_variables, :doned, :shared, :defined_methods
      def initialize(source, precompile:, debug:, shared:)
        @precompile, @debug, @shared = precompile, debug, shared
        @doned, @defined_methods, @defined_variables = Set.new, Set.new, Set.new
        @seq, @main = 0, false
        @ast = RubyVM::AbstractSyntaxTree.parse_file(source)
      end

      def compile_shared_option = %w(-shared -fPIC)

      def register_var_and_method(node)
        return unless node.kind_of?(RubyVM::AbstractSyntaxTree::Node)
        type = node.type
        variables, *_ = node.children
        case type
        when :SCOPE
          variables.each { |v| @defined_variables << v }
        when :DEFN
          @defined_methods << variables
        end
        node.children.each { |n| register_var_and_method(n) }
        nil
      end

      def already_build_methods? = defined_methods.sort == @doned.to_a.sort

      def to_elf(input: precompile, compiler: "gcc", compiler_options: ["-O0"], debug: false)
        base_name = File.basename(input, ".*")
        name = shared ? "lib#{base_name}.so" : base_name
        if compiler.nil?
          Vaporware::Compiler::Assemble.compile!(name, input)
        else
          compile_commands = [compiler, *compiler_options, "-o", name, input].compact
          call_compiler(compile_commands)
        end

        File.delete(input) unless debug
        nil
      end

      def call_compiler(compile_commands) = IO.popen(compile_commands).close

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
          next unless child.kind_of?(RubyVM::AbstractSyntaxTree::Node)
          to_asm(child, output, true)
        end
        ret(output)
        @doned << method
        nil
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
          to_asm(arg, output, method_tree)
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

      def to_asm(node, output, method_tree = false)
        return unless node.kind_of?(RubyVM::AbstractSyntaxTree::Node)
        type = node.type
        center = case type
        when :LIT, :INTEGER
          output.puts "  push #{node.children.last}"
          return
        when :LIST, :BLOCK
          node.children.each { |n| to_asm(n, output, method_tree) }
          return
        when :SCOPE
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
            to_asm(child, output)
          end
          return
        when :DEFN
          name, _ = node.children
          method(name, node, output)
          return
        when :LVAR
          return if method_tree
          name = node.children.last
          lvar(name, output)
          # lvar
          output.puts "  pop rax"
          output.puts "  mov rax, [rax]"
          output.puts "  push rax"
          return
        when :LASGN
          name, right = node.children

          # rvar
          lvar(name, output)
          to_asm(right, output, method_tree)

          output.puts "  pop rdi"
          output.puts "  pop rax"
          output.puts "  mov [rax], rdi"
          output.puts "  push rdi"
          output.puts "  pop rax"
          return
        when :IF
          cond, tblock, fblock = node.children
          to_asm(cond, output)
          output.puts "  pop rax"
          output.puts "  push rax"
          output.puts "  cmp rax, 0"
          if fblock
            output.puts "  je .Lelse#{seq}"
            to_asm(tblock, output, method_tree)
            ret(output)
            output.puts "  jmp .Lend#{seq}"
            output.puts ".Lelse#{seq}:"
            to_asm(fblock, output, method_tree)
            ret(output)
            output.puts ".Lend#{seq}:"
          else
            output.puts "  je .Lend#{seq}"
            to_asm(tblock, output, method_tree)
            ret(output)
            output.puts ".Lend#{seq}:"
          end
          @seq += 1
          return
        when :WHILE
          cond, tblock = node.children
          output.puts ".Lbegin#{seq}:"
          to_asm(cond, output, method_tree)
          output.puts "  pop rax"
          output.puts "  push rax"
          output.puts "  cmp rax, 0"
          output.puts "  je .Lend#{seq}"
          to_asm(tblock, output, method_tree)
          output.puts "  jmp .Lbegin#{seq}"
          output.puts ".Lend#{seq}:"
          @seq += 1
          return
        when :OPCALL
          left, center, right = node.children
          to_asm(left, output, method_tree) unless left.nil?
          if left.nil?
            call_method(node, output, method_tree)
          else
            to_asm(right, output, method_tree)
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
