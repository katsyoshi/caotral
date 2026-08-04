require_relative "../../test_suite"

class Caotral::Linker::LayoutTest < Test::Unit::TestCase
  attr_reader :elf, :shstrtab
  def setup
    @elf = Caotral::Binary::ELF.new
    @shstrtab = build_dummy_section(
      name: ".shstrtab",
      body: Caotral::Binary::ELF::Section::Strtab.new
    )
    @elf.header = Caotral::Binary::ELF::Header.new
  end

  def test_layout_without_sections
    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: true, pie: false)
    assert_raise(Caotral::Linker::Error) { layout.apply! }
  end

  def test_layout_without_header
    elf.sections << shstrtab
    elf.header = nil

    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: true, pie: false)
    assert_raise(Caotral::Linker::Error) { layout.apply! }
  end

  def test_layout_minimal_section
    elf.sections << shstrtab
    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: true, pie: false)
    layout.apply!
    assert_equal(1, elf.program_headers.size)
    assert_equal(:LOAD, elf.program_headers[0].type)
    assert_equal(:EXEC, elf.header.type)
    assert_equal(64, elf.header.phoffset)
    assert_equal(56, elf.header.phsize)
    assert_equal(1, elf.header.phnum)
    assert_equal(130, elf.header.shoffset)
    assert_equal(1, elf.header.shnum)
    assert_equal(0, elf.header.shstrndx)
  end

  def test_layout_with_text
    text_section = build_dummy_section(name: ".text", offset: 0x1000)
    elf.sections << text_section
    elf.sections << shstrtab
    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: true, pie: false)
    layout.apply!
    assert_equal(1, elf.program_headers.size)
    assert_equal(:LOAD, elf.program_headers[0].type)
    assert_equal(0x1000, text_section.header.offset)
  end
  def test_layout_with_pie
    elf.sections << build_dummy_section(name: ".interp")
    elf.sections << shstrtab
    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: false, pie: true)
    layout.apply!
    assert_equal(4, elf.program_headers.size)
    assert_equal(:PHDR, elf.program_headers[0].type)
    assert_equal(:LOAD, elf.program_headers[1].type)
    assert_equal(:INTERP, elf.program_headers[2].type)
    assert_equal(:GNU_STACK, elf.program_headers[3].type)
    assert_equal(:DYN, elf.header.type)
  end

  def test_layout_with_dynamic
    elf.sections << build_dummy_section(name: ".dynamic")
    elf.sections << shstrtab
    layout = Caotral::Linker::Layout.new(elf:, shared: true, executable: false, pie: false)
    layout.apply!
    assert_equal(3, elf.program_headers.size)
    assert_equal(:LOAD, elf.program_headers[0].type)
    assert_equal(:DYNAMIC, elf.program_headers[1].type)
    assert_equal(:GNU_STACK, elf.program_headers[2].type)
    assert_equal(:DYN, elf.header.type)
  end

  def test_layout_sections
    text = build_dummy_section(name: ".text", body: "abc".b, addralign: 16)
    data = build_dummy_section(name: ".data", body: "def".b, addralign: 8)
    elf.sections << text
    elf.sections << data
    elf.sections << shstrtab
    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: true, pie: false)
    layout.apply!

    assert_equal(128, text.header.offset)
    assert_equal(3, text.header.size)
    assert_equal(136, data.header.offset)
    assert_equal(3, data.header.size)
    assert_equal(139, shstrtab.header.offset)
    assert_equal(22, shstrtab.header.size)
    assert_equal(".text\0.data\0.shstrtab\0", shstrtab.body.names)
  end

  private
  def build_dummy_section(name:, body: "".b, addralign: 1, offset: 0)
    header = Caotral::Binary::ELF::SectionHeader.new
    header.set!(addralign:, offset:)

    Caotral::Binary::ELF::Section.new(header:, body:, section_name: name)
  end
end
