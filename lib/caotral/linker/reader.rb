require "stringio"
require_relative "elf"
require_relative "elf/section"
require_relative "elf/section_header"
require_relative "elf/section/strtab"
require_relative "elf/section/symtab"
require_relative "elf/section/rel"

module Caotral
  class Linker
    class Reader
      attr_reader :context
      def self.read!(input:, debug: false, linker_options: []) = new(input:, debug:, linker_options:).read

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
        shentsize = header[58, 2].unpack("S<").first
        shnum = header[60, 2].unpack("S<").first
        shstrndx = header[62, 2].unpack("S<").first
        @context.header.set!(entry:, phoffset:, shoffset:, shnum:, shstrndx:)

        @bin.pos = shoffset
        shnum.times do |i|
          sh_entry = @bin.read(shentsize)
          name = sh_entry[0, 4].unpack("L<").first
          type_val = sh_entry[4, 4].unpack("L<").first
          flags = sh_entry[8, 8].unpack("Q<").first
          addr = sh_entry[16, 8].unpack("Q<").first
          offset = sh_entry[24, 8].unpack("Q<").first
          size = sh_entry[32, 8].unpack("Q<").first
          link = sh_entry[40, 4].unpack("L<").first
          info = sh_entry[44, 4].unpack("L<").first
          addralign = sh_entry[48, 8].unpack("Q<").first
          entsize = sh_entry[56, 8].unpack("Q<").first
          type_sym = type(type_val)
          section_header = Caotral::Linker::ELF::SectionHeader.new
          section_header.set!(name:, type: type_val, flags:, addr:, offset:, size:, link:, info:, addralign:, entsize:)
          section_name = i == shstrndx ? ".shstrtab" : nil
          args = { type: type_sym, section_name: }.compact
          section = Caotral::Linker::ELF::Section.new(**args)
          section.header = section_header
          @context.sections.add(section)
        end
        shstrtab = @context.sections[shstrndx].tap do |shstrtab|
          @bin.pos = shstrtab.header.offset
          names = @bin.read(shstrtab.header.size)
          shstrtab.body = Caotral::Linker::ELF::Section::Strtab.new(names)
          shstrtab
        end

        names = shstrtab.body.names

        @context.sections.each_with_index do |section, i|
          next if i == shstrndx || section.header.name == 0
          offset = section.header.name
          section.section_name = names.byteslice(offset..).split("\0", 2).first
          type = section.header.type
          @bin.pos = section.header.offset
          body_bin = @bin.read(section.header.size)
          section.body = case type
                         when :strtab
                           Caotral::Linker::ELF::Section::Strtab.new(body_bin)
                         when :symtab
                           symtab_entsize = section.header.entsize
                           count = body_bin.bytesize / symtab_entsize
                           count.times.map do |i|
                             sym_bin = body_bin[i * symtab_entsize, symtab_entsize]
                             name = sym_bin[0, 4].unpack1("L<")
                             info = sym_bin[4, 1].unpack1("C")
                             other = sym_bin[5, 1].unpack1("C")
                             shndx = sym_bin[6, 2].unpack1("S<")
                             value = sym_bin[8, 8].unpack1("Q<")
                             size = sym_bin[16, 8].unpack1("Q<")
                             Caotral::Linker::ELF::Section::Symtab.new.set!(name:, info:, other:, shndx:, value:, size:)
                           end
                         when :rel, :rela
                           rela = type == :rela
                           rel_entsize = section.header.entsize
                           rel_entsize = rela ? 24 : 16 if rel_entsize == 0
                           count = body_bin.bytesize / rel_entsize
                           count.times.map do |i|
                              rel_bin = body_bin.byteslice(i * rel_entsize, rel_entsize)
                              offset = rel_bin[0, 8].unpack1("Q<")
                              info = rel_bin[8, 8].unpack1("Q<")
                              addend = rela ? rel_bin[16, 8].unpack1("q<") : nil
                              Caotral::Linker::ELF::Section::Rel.new(addend: rela).set!(offset:, info:, addend:)
                           end
                         when :progbits
                           body_bin
                         end
        end

        strtab = @context.sections[".strtab"]
        @context.sections.select { it.header.type == :symtab }.each do |symtab|
          symtab.body.each do |sym|
            name_offset = sym.name_offset
            sym.name_string = strtab.body.lookup(name_offset)
          end
        end

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

      def type(num) = Caotral::Linker::ELF::SectionHeader::SHT_BY_VALUE.fetch(num, :unknown)
    end
  end
end
