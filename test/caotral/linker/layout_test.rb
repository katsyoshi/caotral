require_relative "../../test_suite"

class Caotral::Linker::LayoutTest < Test::Unit::TestCase
  attr_reader :elf
  def setup = (@elf = Caotral::Binary::ELF.new)
  def test_layout
    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: true, pie: false)
    layout.apply!
    assert_equal(1, elf.program_headers.size)
    assert_equal(:LOAD, elf.program_headers[0].type)
  end
  def test_layout_with_pie
    elf.sections << build_dummy_section(".interp")
    layout = Caotral::Linker::Layout.new(elf:, shared: false, executable: false, pie: true)
    layout.apply!
    assert_equal(4, elf.program_headers.size)
    assert_equal(:PHDR, elf.program_headers[0].type)
    assert_equal(:LOAD, elf.program_headers[1].type)
    assert_equal(:INTERP, elf.program_headers[2].type)
    assert_equal(:GNU_STACK, elf.program_headers[3].type)
  end

  def test_layout_with_dynamic
    elf.sections << build_dummy_section(".dynamic")
    layout = Caotral::Linker::Layout.new(elf:, shared: true, executable: false, pie: false)
    layout.apply!
    assert_equal(3, elf.program_headers.size)
    assert_equal(:LOAD, elf.program_headers[0].type)
    assert_equal(:DYNAMIC, elf.program_headers[1].type)
    assert_equal(:GNU_STACK, elf.program_headers[2].type)
  end

  private
  def build_dummy_section(name)
    Caotral::Binary::ELF::Section.new(
      header: Caotral::Binary::ELF::SectionHeader.new,
      body: "".b,
      section_name: name
    )
  end
end
