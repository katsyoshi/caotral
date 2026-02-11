require "stringio"

module Caotral
  module Binary
    class ELF
      class Reader
        attr_reader :context
        def self.read!(input:, debug: false, linker_options: []) = new(input:, debug:, linker_options:).read

        def initialize(input:, debug: false, linker_options: [])
          @input = decision(input)
          @bin = StringIO.new(@input.read)
          @context = Caotral::Binary::ELF.new
          @context.header = Caotral::Binary::ELF::Header.new
        end

        def read
          header = @bin.read(0x40)
          ident = header[0, 16]
          raise "Not ELF file" unless ident == Caotral::Binary::ELF::Header::IDENT_STR

          type = header[16, 2].unpack1("S<")
          arch = header[18, 2].unpack1("S<")
          entry = header[24, 8].unpack1("Q<")
          phoffset = header[32, 8].unpack1("Q<")
          shoffset = header[40, 8].unpack1("Q<")
          phsize = header[54, 2].unpack1("S<")
          phnum = header[56, 2].unpack1("S<")
          shentsize = header[58, 2].unpack1("S<")
          shnum = header[60, 2].unpack1("S<")
          shstrndx = header[62, 2].unpack1("S<")
          @context.header.set!(type:, arch:, entry:, phoffset:, phsize:, phnum:, shoffset:, shnum:, shstrndx:)

          @bin.pos = phoffset
          phnum.times do |i|
            ph_entry = @bin.read(phsize)
            type = ph_entry[0, 4].unpack1("L<")
            flags = ph_entry[4, 4].unpack1("L<")
            offset = ph_entry[8, 8].unpack1("Q<")
            vaddr = ph_entry[16, 8].unpack1("Q<")
            paddr = ph_entry[24, 8].unpack1("Q<")
            filesz = ph_entry[32, 8].unpack1("Q<")
            memsz = ph_entry[40, 8].unpack1("Q<")
            align = ph_entry[48, 8].unpack1("Q<")
            ph = Caotral::Binary::ELF::ProgramHeader.new
            ph.set!(type:, flags:, offset:, vaddr:, paddr:, filesz:, memsz:, align:)
            @context.program_headers.push(ph)
          end

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
            section_header = Caotral::Binary::ELF::SectionHeader.new
            section_header.set!(name:, type: type_val, flags:, addr:, offset:, size:, link:, info:, addralign:, entsize:)
            section_name = i == shstrndx ? ".shstrtab" : nil
            section = Caotral::Binary::ELF::Section.new(header: section_header, section_name:, body: nil)
            @context.sections.push(section)
          end

          shstrtab = @context.sections[shstrndx].tap do |shstrtab|
            @bin.pos = shstrtab.header.offset
            names = @bin.read(shstrtab.header.size)
            shstrtab.body = Caotral::Binary::ELF::Section::Strtab.new(names)
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
                             Caotral::Binary::ELF::Section::Strtab.new(body_bin)
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
                               Caotral::Binary::ELF::Section::Symtab.new.set!(name:, info:, other:, shndx:, value:, size:)
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
                               Caotral::Binary::ELF::Section::Rel.new(addend: rela).set!(offset:, info:, addend:)
                             end
                           when :dynamic
                             dyn_entsize = section.header.entsize
                             dyn_entsize = 16 if dyn_entsize.zero?
                             count = body_bin.bytesize / dyn_entsize
                             count.times.map do |i|
                               dyn_bin = body_bin.byteslice(i * dyn_entsize, dyn_entsize)
                               tag = dyn_bin[0, 8].unpack1("Q<")
                               un = dyn_bin[8, 8].unpack1("Q<")
                               Caotral::Binary::ELF::Section::Dynamic.new.set!(tag:, un:)
                             end
                           when :progbits
                             body_bin
                           end
          end

          strtab = @context.find_by_name(".strtab")
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

        def validate_relocations
          rela_dyn = @context.sections.find { |section| section.section_name.to_s == ".rela.dyn" }
          pt_load = @context.program_headers.find { |ph| ph.type == :LOAD }
          dynamic = @context.sections.find { |section| section.section_name.to_s == ".dynamic" }
          unless rela_dyn && pt_load && dynamic
            data = [
              rela_dyn ? nil : ".rela.dyn section",
              pt_load ? nil : "LOAD program header",
              dynamic ? nil : ".dynamic section"
            ].compact.join(", ")
            raise Caotral::Binary::ELF::Error, "Missing required relocations inputs: #{data}"
          end
          addr = rela_dyn.header.addr
          size = rela_dyn.header.size
          dynamic.body.each do |dyn|
            val = nil
            val = addr if dyn.rela?
            val = size if dyn.rela_size?
            val = 24 if dyn.rela_ent?
            next unless val
            if dyn.un != val
              raise Caotral::Binary::ELF::Error, "Invalid dynamic section entry: expected #{val}, got #{dyn.un}"
            end
          end

          valid_range = (pt_load.vaddr...(pt_load.vaddr + pt_load.memsz))
          unless rela_dyn.body.all? { |rel| valid_range.include?(rel.offset) }
            raise Caotral::Binary::ELF::Error, "Relocation entries in .rela.dyn exceed LOAD segment range"
          end

          true
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

        def type(num) = Caotral::Binary::ELF::SectionHeader::SHT_BY_VALUE.fetch(num, :unknown)
      end
    end
  end
end
