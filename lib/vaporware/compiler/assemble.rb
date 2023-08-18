# frozen_string_literal: true

module Vaporware
  class Compiler
    class Assemble
      EXEC_ELF_HEADER = %w(
        7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
        01 00 3e 00 01 00 00 00 00 00 00 00 00 00 00 00
        00 00 00 00 00 00 00 00 20 01 00 00 00 00 00 00
        00 00 00 00 40 00 00 00 00 00 40 00 08 00 07 00
      ).map { _1.to_i(16) }.pack("C*")

      NOTE_GNU_PROPERTY_SECTION = %w(
        04 00 00 00 20 00 00 00 05 00 00 00 47 4e 55 00
        02 00 01 c0 04 00 00 00 00 00 00 00 00 00 00 00
        01 00 01 c0 04 00 00 00 01 00 00 00 00 00 00 00
      ).map { _1.to_i(16) }.pack("C*")

      SYMTAB_SECTION = %w(
        00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
        00 00 00 00 00 00 00 00 01 00 00 00 10 00 01 00
        00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
      ).map { _1.to_i(16) }.pack("C*")

      SHSYMTAB_SECTION = %w(
        00 2e 73 79 6d 74 61 62 00 2e 73 74 72 74 61 62
        00 2e 73 68 73 74 72 74 61 62 00 2e 74 65 78 74
        00 2e 64 61 74 61 00 2e 62 73 73 00 2e 6e 6f 74
        65 2e 67 6e 75 2e 70 72 6f 70 65 72 74 79 00
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
      def self.assemble!(input, output = File.basename(input, ".*") + ".o") = new(input, output).assemble

      def initialize(input, output = File.basename(input, ".*") + ".o")
        @input, @output = input, output
        @target_file = File.open(output, "wb")
      end

      def assemble(assemble_command: "as", assemble_options: [], input: @input, f: @target_file)
        read = { main: false }
        opecodes = []
        program_size = 0
        File.open(input, "r") do |r|
          r.each_line do |line|
            read[:main] = /main:/.match(line) unless read[:main]
            next unless read[:main] && !/main:/.match(line)
            op, *args = line.split(/\s+/).reject{ _1 == "" }.map { _1.gsub(/,/, "") }
            puts "% 10x: %s\t%s\t%s" % [program_size, opecode(op, args).map{ "%02x" % _1 }.join(" ").ljust(25), op, args.join(", ")]
            opecodes << opecode(op, args).pack("C*")
            program_size += opecodes.last.bytesize
          end
        end
        f.write(EXEC_ELF_HEADER)
        opecodes << [0].pack("C*") until opecodes.map(&:bytesize).sum % 8 == 0
        opecodes.each { |op| f.write(op) }
        section_headers = section_header(str_section_names: "main")
        section_headers << [0].pack("C*") until section_headers.map(&:bytesize).sum % 8 == 0
        section_headers << null_section_header
        ps = ("%016x" % program_size).scan(/.{1,2}/).reverse.map { |p| p.to_i(16) }
        section_headers << text_section_header(name: [0x1b, *[0]*3], size: ps)
        section_headers << data_section_header
        section_headers << bss_section_header
        section_headers << note_section_header
        section_headers << symtab_section_header
        section_headers << strtab_section_header(size: [0x06, *[0] * 7])
        section_headers << shstrtab_section_header
        section_headers.map { |section| f.write(section) }
        f.close
        f.path
      end

      private

      def section_header(str_section_names:)
        [
          NOTE_GNU_PROPERTY_SECTION,
          SYMTAB_SECTION,
          start_table_section(str_section_names),
          SHSYMTAB_SECTION,
        ]
      end

      def start_table_section(main = "main")
        b = main.bytes << 0
        b.unshift 0 until b.size % 2 ==0
        b.pack("C*")
      end

      def null_section_header = section_headers

      def text_section_header(name: [0x1b, *[0] * 3], offset: [0x40, *[0]* 7], size:)
        type = [1, *[0] * 3]
        flags = [6, *[0] * 7]
        addralign = [1, *[0] * 7]
        section_headers(name:, type:, flags:, size:, offset:, addralign:)
      end

      def data_section_header(offset: [0x72, *[0]*7])
        name = [0x21, *[0] * 3]
        type = [1, *[0] * 3]
        flags = [3, *[0] * 7]
        addralign = [1, *[0] * 7]
        section_headers(name:, type:, flags:, offset:, addralign:)
      end

      def bss_section_header(offset: [0x72, *[0]*7])
        name = [0x27, *[0] * 3]
        type = [8, *[0] * 3]
        flags = [3, *[0] * 7]
        addralign = [1, *[0]* 7]
        section_headers(name:, type:, flags:, offset:, addralign:)
      end

      def note_section_header(offset: [0x78, *[0]*7])
        name = [0x2c, *[0] * 3]
        type = [0x07, *[0] * 3]
        flags = [0x02, *[0] * 7]
        size = [0x30, *[0] * 7]
        addralign = [0x08, *[0] * 7]
        section_headers(name:, type:, flags:, offset:, size:, addralign:)
      end

      def symtab_section_header(name: [0x01, *[0] * 3], offset: [0xa8, *[0] * 7], size: [0x30, *[0] * 7])
        type = [0x02, *[0]* 3]
        link = [0x06, *[0] * 3]
        info = [0x01, *[0] * 3]
        addralign = [0x08, *[0] * 7]
        entsize = [0x18, *[0] * 7]
        section_headers(name:, type:, offset:, size:, link:, info:, addralign:, entsize:)
      end

      def strtab_section_header(name: [0x09, *[0] * 3], offset: [0xd8, *[0] * 7], size:)
        type = [0x03, *[0] * 3]
        addralign = [0x01, *[0]*7]
        section_headers(name:, type:, offset:, size:, addralign:)
      end

      def shstrtab_section_header(name: [0x11, *[0] * 3], offset: [0xde, *[0] * 7], size: [0x3f, *[0] * 7])
        type = [0x03, *[0] * 3]
        addralign = [0x01, *[0] * 7]
        section_headers(name:, type:, offset:, size:, addralign:)
      end

      def section_headers(
        name: [0]*4, type: [0]*4, flags: [0]*8, addr: [0]*8,
        offset: [0]*8, size: [0]*8, link: [0]*4, info: [0]*4,
        addralign: [0]*8, entsize: [0]*8) =
        [name, type, flags, addr, offset, size, link, info, addralign, entsize].flatten.pack("C*")

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
