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
    dynamic = elf.sections.find { |s| s.section_name.to_s == ".dynamic" }
    rela_plt = elf.sections.find { |s| s.section_name.to_s == ".rela.plt" }
    jmprel = dynamic.body.find { |dt| dt.jmp_rel? }
    plt_rel_size = dynamic.body.find { |dt| dt.plt_rel_size? }
    plt_rel = dynamic.body.find { |dt| dt.plt_rel? }
    plt_got = dynamic.body.find { |dt| dt.plt_got? }
    dynsym = elf.sections.find { |s| s.section_name.to_s == ".dynsym" }
    got_plt = elf.sections.find { |s| s.section_name.to_s == ".got.plt" }
    dyn_sym_index = elf.sections.index { |s| dynsym == s }
    got_plt_index = elf.sections.index { |s| got_plt == s }
    assert_include(section_names, ".plt")
    assert_include(section_names, ".dynstr")
    assert_include(section_names, ".dynsym")
    assert_include(section_names, ".dynamic")
    assert_include(section_names, ".rela.plt")
    assert_equal(rela_plt.header.entsize, 24)
    assert_equal(rela_plt.header.link, dyn_sym_index)
    assert_equal(rela_plt.header.info, got_plt_index)

    assert_equal(jmprel.un, rela_plt.header.addr)
    assert_equal(plt_rel_size.un, rela_plt.header.size)
    assert_equal(plt_rel.un, 7)
    assert_equal(plt_got.un, got_plt.header.addr)
  end
end
