# frozen_string_literal: true
module Vaporware
  class Compiler
    class Linker
      DEFAULT_LIBRARY_PATH = %w(/lib64/libc.so.6 /usr/lib64/crt1.o /usr/lib64/crtn.o)
      def self.link!(source, dest = "a.out", linker: "mold", lib_path: [], options: []) = new(source, dest, linker:, lib_path:, options:)

      def initialize(input, output = "a.out", linker: "mold", lib_path: [], options: [])
        @input, @output, @linker = input, output, linker
        @lib_path = DEFAULT_LIBRARY_PATH + lib_path
        @options = options
      end

      def link = IO.popen(link_command).close

      private
      def link_command = %Q|#{@linker} -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o #{@output} #{@lib_path.join(' ')} #{@input}|.split(/\s+/)
    end
  end
end
