require_relative "../../test_suite"

class Caotral::Linker::PIEObjectLinkingTest < Test::Unit::TestCase
  include TestProcessHelper
  def setup
    @inputs = ["pie.o"]
    @output = "pie"
    path = Pathname.new("sample/C/shared-object.c").to_s
    IO.popen(["gcc", "-fPIE", "-c", "-o", @inputs.first, "%s" % path]).close
  end

  def teardown
    File.delete(@inputs[0]) if File.exist?(@inputs[0])
    File.delete(@output) if File.exist?(@output)
  end

  def test_pie_object
    Caotral::Linker.link!(inputs: @inputs, output: @output, linker: "self", executable: false, pie: true)
    elf = Caotral::Binary::ELF::Reader.read!(input: @output, debug: false)
    section_names = elf.sections.map(&:section_name)
    assert_include(section_names, ".dynstr")
    assert_include(section_names, ".dynsym")
    assert_include(section_names, ".dynamic")
    assert_include(section_names, ".interp")
    assert_equal(:DYN, elf.header.type)
    assert_equal(:AMD64, elf.header.arch)
  end
end
