# frozen_string_literal: true

module Vaporware
  class Compiler
    class Assemble
      EXEC_ELF_HEADER = %w(
        7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
        01 00 3e 00 01 00 00 00 b0 00 40 00 00 00 00 00
        40 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
        00 00 00 00 40 00 38 00 00 00 40 00 00 00 00 00
      ).map { _1.to_i(16) }.pack("C*")

      PREFIX = {
        REX_W: 0x48,
      }

      REGISTER_CODE = {
        RAX: 0,
        RDI: 7,
      }

      OPECODE = {
        ADD: 0x01,
        CQO: 0x99,
        IDIV: 0xf7,
        IMUL: 0x0f,
        MOV: 0x89,
        SUB: 0x83,
      }.freeze

      attr_reader :input, :output
      def self.assemble!(input, output = File.basename(input, ".*")) = new(input, output).assemble

      def initialize(input, output = File.basename(input, ".*") + ".o")
        @input, @output = input, output
        @target_file = File.open(output, "wb")
      end

      def assemble(assemble_command: "as", assemble_options: [], input: @input, f: @target_file)
        read = { main: false }
        opecodes = []
        l = 0
        File.open(input, "r") do |r|
          r.each_line do |line|
            read[:main] = /main:/.match(line) unless read[:main]
            next unless read[:main] && !/main:/.match(line)
            op, *args = line.split(/\s+/).reject{ _1 == "" }.map { _1.gsub(/,/, "") }
            puts "% 10x: %s\t%s\t%s" % [l, opecode(op, args).map{ "%02x" % _1 }.join(" ").ljust(25), op, args.join(", ")]
            opecodes << opecode(op, args).pack("C*")
            l+=opecodes.last.bytesize
          end
        end
        f.write(EXEC_ELF_HEADER)
        # f.write(ELF_PROGRAM_HEADER)
        opecodes.each { f.write(_1) }
        f.close
        f.path
      end

      private

      def opecode(op, args)
        case op
        when "push"
          push(args)
        when "mov"
          [PREFIX[:REX_W], *mov(op, *args)]
        when "sub", "add", "imul", "cqo", "idiv"
          [PREFIX[:REX_W], *calc(op, *args)]
        when "pop"
          pop(args)
        when "ret"
          [0xc3]
        end
      end

      def mov(op, *arguments)
        reg = case arguments
        in ["rbp", "rsp"]
          [0xe5]
        in ["rsp", "rbp"]
          [0xec]
        else
          arguments&.map { reg(_1) }
        end
        [OPECODE[op.upcase.to_sym], *reg]
      end

      def calc(op, *arguments)
        ope_code = OPECODE[op.upcase.to_sym]
        case [op, *arguments]
        in ["sub", "rax", "rdi"]
          [0x29, 0xf8]
        in ["add", "rax", "rdi"]
          [ope_code, 0xf8]
        in ["imul", "rax", "rdi"]
          [ope_code, 0xaf, 0xc7]
        in ["idiv", "rdi"]
          [ope_code, 0xff]
        in ["sub", "rsp", *num]
          [ope_code, 0xec, *num.map { |n| n.to_i(16) }]
        in ["cqo"]
          [0x99]
        end
      end

      def push(args)
        case args
        in ["rbp"] | ["rdi"]
          [0x55]
        in ["rax"]
          [0x50]
        else
          [0x6a, *args.map { reg(_1) }]
        end
      end

      def pop(args)
        case args
        in ["rax"] | ["rdi"]
          [0x58 + REGISTER_CODE[args.first.upcase.to_sym]]
        in ["rbp"]
          [0x5d]
        end
      end

      def reg(r)
        case r
        in "rsp"
          0xec
        in "rbp"
          0x5e
        in "rax"
          0x29
        in "rdi"
          0xf8
        in /\d+/
          ("%02x" % r).to_i(16)
        end
      end
    end
  end
end
