# frozen_string_literal: true
require_relative "linker/reader"
require_relative "linker/writer"

module Caotral
  class Linker
    def self.link!(input:, output: "a.out", linker: "mold", debug: false, shared: false) = new(input:, output:, linker:, debug:, shared:).link

    def initialize(input:, output: "a.out", linker: "mold", linker_options: [], shared: false, debug: false)
      @input, @output, @linker = input, output, linker
      @options = linker_options
      @debug, @shared = debug, shared
    end

    def link(input: @input, output: @output, debug: @debug, shared: @shared)
      return to_elf(input:, output:, debug:) if @linker == "self"

      IO.popen(link_command).close
    end

    def link_command(input: @input, output: @output, debug: @debug, shared: @shared)
      ld_path = []

      if @shared
        ld_path << "--shared"
        ld_path << "#{libpath}/crti.o"
        ld_path << "#{gcc_libpath}/crtbeginS.o"
        ld_path << "#{gcc_libpath}/crtendS.o"
      else
        ld_path << "-dynamic-linker"
        ld_path << "/lib64/ld-linux-x86-64.so.2"
        ld_path << "#{libpath}/crt1.o"
        ld_path << "#{libpath}/crti.o"
        ld_path << "#{gcc_libpath}/crtbegin.o"
        # for not static compile
        ld_path << "#{gcc_libpath}/crtend.o"
      end

      ld_path << "#{libpath}/libc.so"
      ld_path << "#{libpath}/crtn.o"
      cmd = [@linker, "-o", @output, "-m", "elf_x86_64", *@options, *ld_path, @input].join(' ')
      puts cmd if @debug
      cmd
    end

    def libpath = @libpath ||= File.dirname(Dir.glob("/usr/lib*/**/crti.o").last)
    def gcc_libpath = @gcc_libpath ||= File.dirname(Dir.glob("/usr/lib/gcc/x86_64-*/*/crtbegin.o").last)

    def to_elf(input: @input, output: @output, debug: @debug)
      elf_obj = Caotral::Linker::Reader.new(input:, debug:).read
      Caotral::Linker::Writer.new(elf_obj:, output:, debug:).write
    end
  end
end
