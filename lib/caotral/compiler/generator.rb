# frozen_string_literal: true

require_relative "analyzer"
require_relative "emitter"

module Caotral
  class Compiler
    class Generator
      REGISTER = %w(rdi rsi rdx rcx r8 r9)
      attr_reader :precompile, :shared
      def initialize(input:, output: File.basename(input, "*") + ".s", debug: false, shared: false)
        @source, @precompile, @debug, @shared = input, output, debug, shared
        @ast = RubyVM::AbstractSyntaxTree.parse_file(@source)
      end

      def compile
        @context = Caotral::Compiler::Analyzer.analyze(@ast)
        @emitter = Caotral::Compiler::Emitter.new(File.open(@precompile, "w"))

        # prologue
        directive(".intel_syntax noprefix")
        if @context.discovered_methods.empty?
          @context.mark_entry_emitted
          directive(".globl main")
          label("main")
          instruction("push", "rbp")
          instruction("mov", "rbp", "rsp")
          instruction("sub", "rsp", @context.local_variables.size * 8)
          to_asm(@ast)
          epilogue
        else
          prologue_methods
          directive(".globl main") unless @shared
          to_asm(@ast)
        end
      ensure
        @emitter&.close
      end

      private
      def compile_shared_option = %w(-shared -fPIC)
      def already_build_methods? = @context.all_methods_emitted?

      def epilogue
        instruction("mov", "rsp", "rbp")
        instruction("pop", "rbp")
        unless @shared
          instruction("mov", "rdi", "rax")
          instruction("mov", "rax", "0x3C")
          instruction("syscall")
        end
        instruction("ret")
      end

      def prologue_methods
        @context.discovered_methods.each do |name|
          directive(".globl #{name}")
          directive(".type #{name}, @function") if shared
        end
        nil
      end

      def define_method_prologue(function)
        instruction("push", "rbp")
        instruction("mov", "rbp", "rsp")
        unless @context.local_variables.empty?
          instruction("sub", "rsp", lvar_offset(nil) * 8)
          function.parameters.each_with_index do |_, i|
            instruction("mov", "[rbp-#{(i + 1) * 8}]", REGISTER[i])
          end
        end
        nil
      end

      def parse_method(name, function)
        label(name)
        define_method_prologue(function)

        to_asm(function.body, true)

        instruction("pop", "rax")
        ret
        @context.mark_method_emitted(name)
        nil
      end

      def call_method(node, method_tree)
        instruction("mov", "rax", "rsp")
        instruction("mov", "rdi", 16)
        instruction("cqo")
        instruction("idiv", "rdi")
        instruction("mov", "rax", 0)
        instruction("cmp", "rdi", 0)
        instruction("jne", ".Lprecall#{sequence}")
        instruction("push", 0)
        instruction("mov", "rax", 1)
        label(".Lprecall#{sequence}")
        instruction("push", "rax")
        _, name, *args = node.children
        args.each_with_index do |arg, i|
          to_asm(arg, method_tree)
          instruction("pop", REGISTER[i])
        end

        instruction("call", name)
        instruction("pop", "rdi")
        instruction("cmp", "rdi", 0)
        instruction("je", ".Lpostcall#{sequence}")
        instruction("pop", "rdi")
        label(".Lpostcall#{sequence}")
        instruction("push", "rax")
        @context.increment_label_sequence
        nil
      end

      def comp(op)
        instruction("cmp", "rax", "rdi")
        instruction(op, "al")
        instruction("movzb", "rax", "al")
        instruction("push", "rax")
        nil
      end

      def lvar(var)
        instruction("mov", "rax", "rbp")
        instruction("sub", "rax", lvar_offset(var) * 8)
        instruction("push", "rax")
        nil
      end

      def lvar_offset(var)
        return @context.local_variables.size if var.nil?
        @context.local_variables.find_index(var).then do |i|
          raise "unknown local variable...: #{var}" if i.nil?
          i + 1
        end
      end

      def ret
        instruction("mov", "rsp", "rbp")
        instruction("pop", "rbp")
        instruction("ret")
      end

      def to_asm(node, method_tree = false)
        return unless node.kind_of?(RubyVM::AbstractSyntaxTree::Node)
        type = node.type
        center = case type
        when :LIT, :INTEGER
          instruction("push", "0x#{node.children.last.to_s(16)}")
          return
        when :LIST, :BLOCK, :BEGIN
          node.children.each { |n| to_asm(n, method_tree) }
          return
        when :SCOPE
          node.children.each do |child|
            if already_build_methods? && !@context.entry_emitted?
              return if shared
              label("main")
              instruction("push", "rbp")
              instruction("mov", "rbp", "rsp")
              instruction("sub", "rsp", 0)
              instruction("push", "rax")
              @context.mark_entry_emitted
            end
            to_asm(child)
          end
          return
        when :DEFN
          name, _ = node.children
          parse_method(name, @context.functions.fetch(name))
          return
        when :LVAR
          return if method_tree
          name = node.children.last
          lvar(name)
          # lvar
          instruction("pop", "rax")
          instruction("mov", "rax", "[rax]")
          instruction("push", "rax")
          return
        when :LASGN
          name, right = node.children

          # rvar
          lvar(name)
          to_asm(right, method_tree)

          instruction("pop", "rdi")
          instruction("pop", "rax")
          instruction("mov", "[rax]", "rdi")
          instruction("push", "rdi")
          instruction("pop", "rax")
          return
        when :IF
          cond, tblock, fblock = node.children
          to_asm(cond)
          instruction("pop", "rax")
          instruction("push", "rax")
          instruction("cmp", "rax", 0)
          if fblock
            instruction("je", ".Lelse#{sequence}")
            to_asm(tblock, method_tree)
            instruction("pop", "rax")
            instruction("jmp", ".Lend#{sequence}")
            label(".Lelse#{sequence}")
            to_asm(fblock, method_tree)
            instruction("pop", "rax")
            label(".Lend#{sequence}")
          else
            if method_tree
              to_asm(tblock, method_tree)
              ret
            else
              instruction("je", ".Lend#{sequence}")
              to_asm(tblock, method_tree)
              label(".Lend#{sequence}")
            end
          end
          @context.increment_label_sequence
          return
        when :WHILE
          cond, tblock = node.children
          label(".Lbegin#{sequence}")
          to_asm(cond, method_tree)
          instruction("pop", "rax")
          instruction("push", "rax")
          instruction("cmp", "rax", 0)
          instruction("je", ".Lend#{sequence}")
          to_asm(tblock, method_tree)
          instruction("jmp", ".Lbegin#{sequence}")
          label(".Lend#{sequence}")
          @context.increment_label_sequence
          return
        when :OPCALL
          left, center, right = node.children
          to_asm(left, method_tree) unless left.nil?
          if left.nil?
            call_method(node, method_tree)
          else
            to_asm(right, method_tree)
            instruction("pop", "rdi")
          end
          instruction("pop", "rax")
          center
        end

        case center
        when :+
          instruction("add", "rax", "rdi")
          instruction("push", "rax")
        when :-
          instruction("sub", "rax", "rdi")
          instruction("push", "rax")
        when :*
          instruction("imul", "rax", "rdi")
          instruction("push", "rax")
        when :/
          instruction("cqo")
          instruction("idiv", "rdi")
          instruction("push", "rax")
        when :==
          comp("sete")
        when :!=
          comp("setne")
        when :<
          comp("setl")
        when :<=
          comp("setle")
        end
      end

      def instruction(ope, *operands) = @emitter.instruction(ope, *operands)
      def label(name) = @emitter.label(name)
      def directive(row) = @emitter.directive(row)
      def sequence = @context.label_sequence
    end
  end
end
