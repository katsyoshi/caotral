require "caotral/binary/elf"

module Caotral
  class Linker
    class Writer
      include Caotral::Binary::ELF::Utils
      RELOCATION_SECTION_NAMES = [".rela.text", ".rela.dyn", ".rela.data", ".rela.plt"].freeze
      attr_reader :elf_obj, :output, :debug, :program_headers
      def self.write!(elf_obj:, output:, debug: false, executable: true, shared: false)
        new(elf_obj:, output:, debug:, shared:, executable:).write
      end

      def initialize(elf_obj:, output:, debug: false, executable: true, shared: false, pie: false)
        @elf_obj, @output, @debug, @executable, @shared, @pie = elf_obj, output, debug, executable, shared, pie
        @program_headers = elf_obj.program_headers
        @write_sections = elf_obj.sections
      end

      def write
        f = File.open(@output, "wb")

        f.write(@elf_obj.header.build)
        program_headers.each { |ph| f.write(ph.build) }

        write_elf_sections(file: f)

        # relocation
        rel_sections.each { |rel| write_section(file: f, section: rel) }
        write_section(file: f, section: shstrtab_section)
        shoffset = @elf_obj.header.shoffset
        f.seek(shoffset)
        write_section_headers(file: f)
        output
      ensure
        f.close if f
      end

      private
      def write_elf_sections(file:)
        write_section(file:, section: text_section)

        write_section(file:, section: rodata_section) if rodata_section
        write_section(file:, section: data_section) if data_section

        if plt_section
          write_section(file:, section: plt_section)
          raise Caotral::Binary::ELF::Error, "missing .got.plt for .plt" if got_plt_section.nil?
          write_section(file:, section: got_plt_section)
        end

        write_shared_dynamic_sections(file:) if dynamic?
        write_section(file:, section: symtab_section)
        write_section(file:, section: strtab_section)
      end
      def write_section_index(section_name) = @write_sections.index { it.section_name == section_name }

      def write_shared_dynamic_sections(file:)
        write_section(file:, section: interp_section) if interp_section
        write_section(file:, section: dynstr_section) if dynstr_section
        write_section(file:, section: dynsym_section) if dynsym_section
        write_section(file:, section: hash_section) if dynamic?
        write_section(file:, section: dynamic_section) if dynamic_section

        if plt_section
          current_offset = file.pos
          primary, *rest = plt_section.body
          plt_offset = plt_section.header.offset
          got_plt_offset = got_plt_section.header.offset
          file.seek(plt_offset)
          plt_addr = plt_section.header.addr
          got_plt_addr = got_plt_section.header.addr
          # only support x86-64 binaries with PLT
          primary[2..5] = [(got_plt_addr + 8) - (plt_addr + 6)].pack("l<").bytes
          primary[8..11] = [(got_plt_addr + 16) - (plt_addr + 12)].pack("l<").bytes
          slot_offset = 24
          rest.each_with_index do |entry, i|
            entry_addr = plt_addr + 16 + 16 * i
            slot_addr = got_plt_addr + slot_offset + 8 * i
            entry[2..5] = [slot_addr - (entry_addr + 6)].pack("l<").bytes
            entry[7..10] = [i].pack("l<").bytes
            entry[12..15] = [plt_addr - (entry_addr + 16)].pack("l<").bytes
          end
          file.write(primary.flatten.pack("C*"))
          file.write(rest.flatten.pack("C*"))

          file.seek(got_plt_offset)
          primary, secondary, third, *rest = got_plt_section.body
          primary = [dynamic_section.header.addr].pack("Q<").bytes
          rest.each_with_index { |_entry, i| rest[i] = [plt_addr + 22 + 16 * i].pack("Q<").bytes }
          file.write(primary.flatten.pack("C*"))
          file.write(secondary.flatten.pack("C*"))
          file.write(third.flatten.pack("C*"))
          file.write(rest.flatten.pack("C*"))
          file.seek(current_offset)
        end
      end

      def ref_index(section_name)
        return 0 if section_name == ".rela.dyn"
        ref_name = section_name.split(".").filter { |sn| !sn.empty? && sn != "rel" && sn != "rela" }
        ref_name = "." + ref_name.join(".")
        ref = @write_sections.find { |s| s.section_name == ref_name }
        raise Caotral::Binary::ELF::Error, "cannot find reference section for #{section_name}" if ref.nil?
        write_section_index(ref.section_name)
      end

      def link_index(section_name)
        case section_name
        when ".symtab"
          write_section_index(".strtab")
        when ".dynsym", ".dynamic"
          write_section_index(".dynstr")
        when ".hash"
          write_section_index(".dynsym")
        else
          nil
        end
      end

      def write_section_headers(file:)
        symtabndx = write_section_index(".symtab")

        names = shstrtab_section.body
        @write_sections.each do |section|
          header = section.header
          lookup_name = section.section_name
          name = names.offset_of(lookup_name) || 0
          info, entsize = header.info, header.entsize
          link = link_index(section.section_name)
          link = header.link if link.nil?
          if [:rela, :rel].include?(header.type)
            if [".rela.dyn", ".rela.plt"].include?(section.section_name.to_s)
              entsize = 24
            elsif ".rela.text" == section.section_name.to_s
              info = write_section_index(".text")
              entsize = 24
              link = symtabndx
            else
              link = symtabndx
            end
            info = ref_index(section.section_name) unless ".rela.plt" == section.section_name.to_s
          end
          header.set!(name:, info:, link:, entsize:)
          file.write(section.header.build)
        end
      end

      def write_section(file:, section:)
        return unless section

        file.seek(section.header.offset)
        file.write(section.build)
      end

      def dynamic? = (@shared || @pie)

      def text_section = @text_section ||= @write_sections.find { |s| ".text" === s.section_name.to_s }
      def rel_sections = @rel_sections ||= @write_sections.select { |s| RELOCATION_SECTION_NAMES.include?(s.section_name.to_s) }
      def symtab_section = @symtab_section ||= @write_sections.find { |s| ".symtab" === s.section_name.to_s }
      def strtab_section = @strtab_section ||= @write_sections.find { |s| ".strtab" === s.section_name.to_s }
      def shstrtab_section = @shstrtab_section ||= @write_sections.find { |s| ".shstrtab" === s.section_name.to_s }
      def dynstr_section = @dynstr_section ||= @write_sections.find { |s| ".dynstr" === s.section_name.to_s }
      def dynsym_section = @dynsym_section ||= @write_sections.find { |s| ".dynsym" === s.section_name.to_s }
      def dynamic_section = @dynamic_section ||= @write_sections.find { |s| ".dynamic" === s.section_name.to_s }
      def interp_section = @interp_section ||= @write_sections.find { |s| ".interp" === s.section_name.to_s }
      def rela_dyn_section = @rela_dyn_section ||= @write_sections.find { |s| ".rela.dyn" === s.section_name.to_s }
      def data_section = @data_section ||= @write_sections.find { |s| ".data" === s.section_name.to_s }
      def rodata_section = @rodata_section ||= @write_sections.find { |s| ".rodata" === s.section_name.to_s }
      def hash_section = @hash_section ||= @write_sections.find { |s| ".hash" === s.section_name.to_s }
      def plt_section = @plt_section ||= @write_sections.find { |s| ".plt" === s.section_name.to_s }
      def got_plt_section = @got_plt_section ||= @write_sections.find { |s| ".got.plt" === s.section_name.to_s }
      def rela_plt_section = @rela_plt_section ||= @write_sections.find { |s| ".rela.plt" === s.section_name.to_s }
    end
  end
end
