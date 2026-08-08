require "caotral/binary/elf"

module Caotral
  class Linker
    class Writer
      def self.write!(elf_obj:, output:) = new(elf_obj:, output:).write
      def initialize(elf_obj:, output:) = (@elf_obj, @output = elf_obj, output)

      def write
        File.open(@output, "wb") do |file|

          file.write(@elf_obj.header.build)
          @elf_obj.program_headers.each { |ph| file.write(ph.build) }

          write_elf_sections(file:)

          file.seek(@elf_obj.header.shoffset)
          write_section_headers(file:)
        end
        @output
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
