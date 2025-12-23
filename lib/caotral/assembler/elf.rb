class Caotral::Assembler
  class ELF
    class Error < StandardError; end
    class Section; end
    class SectionHeader; end
    module Utils; end

    def initialize(type:, input:, output:, debug:)
      @input, @output = input, output
      @header = Header.new(type:)
      @sections = Sections.new
    end

    def build(input: @input, output: @output, debug: false)
      program_size = 0
      read!(input:)
      init_assemble!

      offset = 0x40
      section_headers = []
      names = []
      bodies = {
        null: nil,
        text: nil,
        data: nil,
        bss: nil,
        note: nil,
        symtab: nil,
        strtab: nil,
        shstrtab: nil,
      }
      name_idx = 0
      padding = nil
      @sections.each do |section|
        name = section.name
        names << name
        section.body.set!(name: names.join) if name == "\0.shstrtab"
        bin = section.body.build
        size = bin.bytesize
        bin << "\0" until (bin.bytesize % 8) == 0 if ["\0.text", "\0.shstrtab"].include?(name)
        bin << "\0" until ((bin.bytesize + offset) % 8) == 0 if ["\0.shstrtab"].include?(name)
        bodies[section.section_name.to_sym] = bin
        header = section.header
        if offset > 0x40 && size > 0 && padding&.>(0)
          offset += padding
          padding = nil
        end
        padding = bin.size - size if size > 0
        header.set!(name: name_idx, offset:, size:) unless name == ""
        offset += size
        section_headers << header.build
        name_idx += name == "" ? 1 : name.size
      end
      @header.set!(shoffset: offset + padding)
      w = File.open(output, "wb")
      w.write([@header.build, *bodies.values, *section_headers].join)
      w.close
      [@header.build, *bodies.values, *section_headers]
    end

    private
    def init_assemble! = (note!; symtab!)

    def read!(input: @input, text: @sections.text.body)
      read = { main: false }
      File.open(input, "r") do |r|
      r.each_line do |line|
        read[:main] = line.match(/main:/) unless read[:main]
        next unless read[:main] && !/main:/.match(line)
        text.assemble!(line)
      end
      end
    end
    def note! = @sections.note.body.null!
    def symtab! = @sections.symtab.body.set!(entsize: 0x18, name: 1, info: 0x10, other: 0, shndx: 1)
  end
end
