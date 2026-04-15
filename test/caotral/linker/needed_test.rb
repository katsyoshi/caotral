require_relative "../../test_suite"

class LinkerNeededTest < Test::Unit::TestCase
  include TestProcessHelper

  def setup
    @input = "needed.o"
    @output = "needed"
  end

  def teardown
    File.delete(@input) if File.exist?(@input)
    File.delete(@output) if File.exist?(@output)
  end

  def test_needed_in_dynamic_section
    compile_path = Pathname.new("sample/C/needed.c").to_s
    IO.popen(["gcc", "-fPIE", "-c", "-o", @input, "%s" % compile_path]).close

    Caotral::Linker.link!(inputs: [@input], output: @output, linker: "self", pie: true, needed: ["libc.so.6"])
    
    elf = Caotral::Binary::ELF::Reader.read!(input: @output, debug: false)
    dynstr = elf.find_by_name(".dynstr")
    dynsym = elf.find_by_name(".dynsym")
    needed = elf.find_by_name(".dynamic").body.select(&:needed?)
    assert_equal(1, needed.size)
    assert_equal(dynstr.body.lookup(needed.first.un), "libc.so.6")
    assert_include(dynsym.body.map(&:name_string), "puts")
  end

  def test_needed_in_executable
    compile_path = Pathname.new("sample/C/needed.c").to_s
    IO.popen(["gcc", "-fPIE", "-c", "-o", @input, "%s" % compile_path]).close

    Caotral::Linker.link!(inputs: [@input], output: @output, linker: "self", pie: true, needed: ["libc.so.6"], executable: true)

    IO.popen(["./#{@output}"]).close
    pid, exit_code = check_process($?.to_i)
    assert_equal(0, exit_code)
  end
end
