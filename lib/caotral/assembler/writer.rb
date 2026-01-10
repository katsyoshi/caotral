require "caotral/binary/elf"

module Caotral
  class Assembler
    class Writer
      SECTION_TYPE_BY_NAME = {
        nil => :null,
        ".symtab" => :symtab,
        ".shstrtab" => :strtab,
        ".strtab" => :strtab,
        ".text" => :progbits,
     }.freeze

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
            link = 0
            type, flags, addralign, info, entsize = [*decide(section)]
            link = @elf_obj.index(".strtab") if ".symtab" == section.section_name
            header.set!(name:, flags:, offset:, size:, type:, info:, link:, entsize:, addralign:)
            f.write(header.build)
          end
          @elf_obj.header.set!(shoffset:, shnum:, shstrndx:)
          f.seek(0)
          f.write(@elf_obj.header.build)
        end
        output
      end
      private_constant :SECTION_TYPE_BY_NAME

      private
      def decide(section)
        type = SECTION_TYPE_BY_NAME[section.section_name]
        [
          _type(type),
          _flag(type),
          _addralign(type, section.section_name),
          _info(type),
          _entsize(type),
        ]
      end 
        
      def _type(type_name) = Caotral::Binary::ELF::SectionHeader::SHT[type_name]

      def _flag(section_type)
        case section_type
        when :progbits
          6
        when :symtab, :strtab
          0
        else
          0
        end
      end

      def _addralign(type, section_name)
        return 1 if type == :progbits && section_name == ".text"
        return 8 if type == :symtab
        1
      end

      def _info(section_type)
        case section_type
        when :symtab
          1
        when :progbits, :strtab
          0
        else
          0
        end
      end
      def _entsize(section_type)
        case section_type
        when :symtab
          24
        when :progbits, :strtab
          0
        else
          0
        end
      end
    end
  end
end
