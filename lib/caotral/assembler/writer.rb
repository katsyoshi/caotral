require "caotral/binary/elf"

module Caotral
  class Assembler
    class Writer
      def self.write!(elf_obj:, output:, debug: false) = new(elf_obj:, output:, debug:).write
      def initialize(elf_obj:, output:, debug: false) = @elf_obj, @output, @debug = elf_obj, output, debug

      def write(output: @output)
        File.open(output, "wb") do |f|
          f.write(@elf_obj.header.build)
          @elf_obj.sections.each do |section|
            next if section.section_name == ".shstrtab"
            case section.body
            in String
              f.write(section.body)
            in Array
              section.body.each do |s|
                f.write(s.build)
              end
            else
              f.write(section.body.build)
            end
          end
          shstrtab = @elf_obj.find_by_name(".shstrtab")
          f.write(shstrtab.body.build)
          shoffset = f.pos
          shnum = @elf_obj.sections.size
          shstrndx = shnum - 1
          @elf_obj.sections.each { |section| f.write(section.header.build) }
          @elf_obj.header.set!(shoffset:, shnum:, shstrndx:)
          f.seek(0)
          f.write(@elf_obj.header.build)
        end
        output
      end
    end
  end
end
