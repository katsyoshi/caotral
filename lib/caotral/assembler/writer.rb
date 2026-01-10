require "caotral/binary/elf"

module Caotral
  class Assembler
    class Writer
      def self.write!(elf_obj:, output:, debug: false) = new(elf_obj:, output:, debug:).write
      def initialize(elf_obj:, output:, debug: false)
        @elf_obj = elf_obj
        @output = output
        @debug = debug
      end

      def write(output: @output)
        File.open(output, "wb") do |f|
          f.write(@elf_obj.header.build)
          shstrtab_names = String.new
          offsets = {}
          @elf_obj.sections.each do |section|
            section_name = section.section_name.to_s
            shstrtab_names << "\0#{section_name}"
            next if section.section_name == ".shstrtab"
            offsets[section_name] = f.pos
            case section.body
            in String
              f.write(section.body)
            in Array
              section.body.each { |s| f.write(s.build) }
            else
              next if section.body.nil?
              f.write(section.body.build)
            end
          end
          shstrtab = @elf_obj.find_by_name(".shstrtab")
          shstrtab.body.names = shstrtab_names << "\0".b
          offsets[".shstrtab"] = f.pos
          f.write(shstrtab.body.build)
          shoffset = f.pos
          shnum = @elf_obj.sections.size
          shstrndx = shnum - 1
          offset = 0
          symtab = @elf_obj.find_by_name(".symtab")
          symtab.header.set!(entsize: 24)
          @elf_obj.sections.each do |section|
            header = section.header
            section_name = section.section_name.to_s
            name = section_name.empty? ? 0 : shstrtab.body.offset_of(section_name)
            body = section.body
            size = case body
                   in String
                     body.size
                   in Array
                     body.map(&:build).map(&:size).sum
                   in NilClass
                     0
                   else
                     body.build.size
                   end
            offset = section.section_name.nil? ? 0 : offsets[section_name]
            type = decide_type(section)
            if ".symtab" == section.section_name
              link = @elf_obj.index(".strtab")
              info = 1
              header.set!(name:, offset:, size:, type:, info:, link:)
            else
              header.set!(name:, offset:, size:, type:)
            end
            f.write(header.build)
          end
          @elf_obj.header.set!(shoffset:, shnum:, shstrndx:)
          f.seek(0)
          f.write(@elf_obj.header.build)
        end
        output
      end

      private def decide_type(section)
        case section.section_name
        when ".text"
          1
        when ".symtab"
          2
        when ".shstrtab", ".strtab"
          3
        else
          0
        end
      end
    end
  end
end
