require "stringio"
require_relative "elf"
module Caotral
  class Linker
    class Reader
      attr_reader :context
      def self.read!(input:, debug: false, linker_options: [])
        new(input:, debug:, linker_options:).read
      end

      def initialize(input:, debug: false, linker_options: [])
        @input = decision(input)
        @bin = StringIO.new(@input.read)
        @context = Caotral::Linker::ELF.new
      end

      def read
        header = @bin.read(0x40)
        ident = header[0, 16]
        raise "Not ELF file" unless ident == Caotral::Linker::ELF::Header::IDENT_STR
    
        entry = header[24, 8].unpack("Q<").first
        phoffset = header[32, 8].unpack("Q<").first
        shoffset = header[40, 8].unpack("Q<").first
        shnum = header[60, 2].unpack("S<").first
        shstrndx = header[62, 2].unpack("S<").first
        @context.header.set!(entry:, phoffset:, shoffset:, shnum:, shstrndx:)

        @bin.pos = shoffset
        @context
      ensure
        @input.close
      end

      private
      def decision(input)
        case input
        when String, Pathname
          File.open(File.expand_path(input.to_s), "rb")
        else
          raise ArgumentError, "wrong input type"
        end
      end
    end
  end
end
