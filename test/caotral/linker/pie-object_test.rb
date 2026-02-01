require_relative "../../test_suite"

class Caotral::Linker::PIEObjectLinkingTest < Test::Unit::TestCase
  include TestProcessHelper
  def setup
    @inputs = ["pie.o"]
    @output = "pie"
    path = Pathname.new("sample/C/pie-object.c").to_s
    IO.popen(["gcc", "-fPIE", "-c", "-o", @inputs.first, "%s" % path]).close
  end

  def teardown
    File.delete(@inputs[0]) if File.exist?(@inputs[0])
    File.delete(@output) if File.exist?(@output)
  end

  def test_non_executable_pie_object
    Caotral::Linker.link!(inputs: @inputs, output: @output, linker: "self", executable: false, pie: true)
    elf = Caotral::Binary::ELF::Reader.read!(input: @output, debug: false)
    section_names = elf.sections.map(&:section_name)
    program_header_types = elf.program_headers.map(&:type)
    interp = elf.find_by_name(".interp")
    dynamic = elf.find_by_name(".dynamic").body.last
    assert_include(program_header_types, :LOAD)
    assert_include(program_header_types, :DYNAMIC)
    assert_include(program_header_types, :INTERP)
    assert_equal(interp.body.split("\0").first, "/lib64/ld-linux-x86-64.so.2")
    assert_equal(dynamic.null?, true)
    assert_include(section_names, ".dynstr")
    assert_include(section_names, ".dynsym")
    assert_include(section_names, ".dynamic")
    assert_include(section_names, ".interp")
    assert_equal(:DYN, elf.header.type)
    assert_equal(:AMD64, elf.header.arch)
    assert_equal(0, elf.header.entry)
  end

  def test_executable_pie_object
    Caotral::Linker.link!(inputs: @inputs, output: @output, linker: "self", pie: true)
    elf = Caotral::Binary::ELF::Reader.read!(input: @output, debug: false)
    section_names = elf.sections.map(&:section_name)
    program_header_types = elf.program_headers.map(&:type)
    interp = elf.find_by_name(".interp")
    dynamic = elf.find_by_name(".dynamic").body.last
    assert_include(program_header_types, :LOAD)
    assert_include(program_header_types, :DYNAMIC)
    assert_include(program_header_types, :INTERP)
    assert_equal(interp.body.split("\0").first, "/lib64/ld-linux-x86-64.so.2")
    assert_equal(dynamic.null?, true)
    assert_include(section_names, ".dynstr")
    assert_include(section_names, ".dynsym")
    assert_include(section_names, ".dynamic")
    assert_include(section_names, ".interp")
    assert_equal(:DYN, elf.header.type)
    assert_equal(:AMD64, elf.header.arch)
    assert_not_equal(0, elf.header.entry)
  end
end
