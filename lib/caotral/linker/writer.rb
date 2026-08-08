require "caotral/binary/elf"

module Caotral
  class Linker
    class Writer
      include Caotral::Binary::ELF::Utils
      attr_reader :elf_obj, :output, :debug, :program_headers
      def self.write!(elf_obj:, output:, debug: false, executable: true, shared: false)
        new(elf_obj:, output:, debug:, shared:, executable:).write
      end

      def initialize(elf_obj:, output:, debug: false, executable: true, shared: false, pie: false)
        @elf_obj, @output, @debug, @executable, @shared, @pie = elf_obj, output, debug, executable, shared, pie
        @program_headers = elf_obj.program_headers
      end

      def write
        File.open(@output, "wb") do |file|

          file.write(@elf_obj.header.build)
          program_headers.each { |ph| file.write(ph.build) }

          write_elf_sections(file:)

          file.seek(@elf_obj.header.shoffset)
          write_section_headers(file:)
        end
        output
      end

      private
      def write_elf_sections(file:) = @elf_obj.sections.each { |section| write_section(file:, section:) }
      def write_section_headers(file:) = @elf_obj.sections.each { |section| file.write(section.header.build) }

      def write_section(file:, section:)
        return unless section

        file.seek(section.header.offset)
        file.write(section.build)
      end
    end
  end
end
