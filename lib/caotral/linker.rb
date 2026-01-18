# frozen_string_literal: true
require_relative "binary/elf/reader"
require_relative "linker/builder"
require_relative "linker/writer"

module Caotral
  class Linker
    def self.link!(inputs:, output: "a.out", linker: "mold", debug: false, shared: false, executable: true)
      new(inputs:, output:, linker:, debug:, shared:, executable:).link
    end

    def initialize(inputs:, output: "a.out", linker: "mold", linker_options: [], executable: true, shared: false, debug: false)
      @inputs, @output, @linker = inputs, output, linker
      @options = linker_options
      @executable, @debug, @shared = executable, debug, shared
    end

    def link(inputs: @inputs, output: @output, debug: @debug, shared: @shared, executable: @executable)
      return to_elf(inputs:, output:, debug:, shared:, executable:) if @linker == "self"

      IO.popen(link_command).close
    end

    def link_command(inputs: @inputs, output: @output)
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
      cmd = [@linker, "-o", @output, "-m", "elf_x86_64", *@options, *ld_path, *inputs].join(' ')
      puts cmd if @debug
      cmd
    end

    def libpath = @libpath ||= File.dirname(Dir.glob("/usr/lib*/**/crti.o").last)
    def gcc_libpath = @gcc_libpath ||= File.dirname(Dir.glob("/usr/lib/gcc/x86_64-*/*/crtbegin.o").last)

    def to_elf(inputs: @inputs, output: @output, debug: @debug, shared: @shared, executable: @executable)
      elf_objs = inputs.map { |input| Caotral::Binary::ELF::Reader.new(input:, debug:).read }
      builder = Caotral::Linker::Builder.new(elf_objs:, debug:, shared:, executable:)
      builder.resolve_symbols
      elf_obj = builder.build
      Caotral::Linker::Writer.new(elf_obj:, output:, debug:, shared:, executable:).write
      File.chmod(0755, output) if executable
      output
    end
  end
end
