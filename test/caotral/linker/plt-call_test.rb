require_relative "../../test_suite"

class Caotral::Linker::PLTCallTest < Test::Unit::TestCase
  def setup
    @inputs = ["plt-call.o"]
    @output = "plt-call"
    path = Pathname.new("sample/C/plt-call.c").to_s
    IO.popen(["gcc", "-fno-pic", "-c", "-o", @inputs[0], "%s" % path]).close
  end

  def teardown
    File.delete(@inputs[0]) if File.exist?(@inputs[0])
    File.delete(@output) if File.exist?(@output)
  end

  def test_plt_call
    Caotral::Linker.link!(inputs: @inputs, output: @output, linker: "self", executable: true, shared: false, pie: true)
    elf = Caotral::Binary::ELF::Reader.read!(input: @output, debug: false)
    section_names = elf.sections.map(&:section_name)
    assert_include(section_names, ".plt")
    assert_include(section_names, ".dynstr")
    assert_include(section_names, ".dynsym")
    assert_include(section_names, ".dynamic")
    assert_include(section_names, ".rela.plt")
  end
end
