# frozen_string_literal: true
require_relative "assembler/elf"
require_relative "assembler/elf/header"
require_relative "assembler/elf/section"
require_relative "assembler/elf/section/note"
require_relative "assembler/elf/section/text"
require_relative "assembler/elf/section/symtab"
require_relative "assembler/elf/section/shsymtab"
require_relative "assembler/elf/section_header"

module Vaporware
  class Compiler
    class Assembler
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

      def self.assemble!(input, output = File.basename(input, ".*") + ".o") = new(input, output).assemble

      def initialize(input, output = File.basename(input, ".*") + ".o", type: :relocator, debug: false)
        @input, @output = input, output
        @target_file = File.open(output, "wb")
        @elf_header = ELF::Header.new(type:)
        @sections = {
          null: { body: nil, header: ELF::SectionHeader.new.null! },
          text: { body: ELF::Section::Text.new, header: ELF::SectionHeader.new.text! },
          note: { body: ELF::Section::Note.new.gnu_property!, header: ELF::SectionHeader.new.note! },
          symtab: { body: ELF::Section::Symtab.new, header: ELF::SectionHeader.new.symtab! },
          strtab: { body: ELF::Section::Strtab.new, header: ELF::SectionHeader.new.strtab! },
          shsymtab: { body: ELF::Section::Shsymtab.new, header: ELF::SectionHeader.new.shsymtab! },
        }
        @debug = debug
      end

      def assemble(assemble_command: "as", assemble_options: [], input: @input, f: @target_file)
        read = { main: false }
        program_size = 0
        text = @section[:text][:body]
        File.open(input, "r") do |r|
          r.each_line do |line|
            read[:main] = /main:/.match(line) unless read[:main]
            next unless read[:main] && !/main:/.match(line)
            text.assemble!(line)
          end
        end
        f.write(@elf_header.build!)
        bins = []
        section_headers = []
        @sections.values.map do |section|
          bins << section[:body].build
          section_headers << section[:header].build
        end

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
