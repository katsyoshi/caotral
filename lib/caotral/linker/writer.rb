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

      def write_shared_dynamic_sections(file:)
        write_section(file:, section: interp_section) if interp_section
        write_section(file:, section: dynstr_section) if dynstr_section
        write_section(file:, section: dynsym_section) if dynsym_section
        write_section(file:, section: hash_section) if dynamic?
        write_section(file:, section: dynamic_section) if dynamic_section
      end

      def write_section_headers(file:)
        @write_sections.each { |section| file.write(section.header.build) }
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
