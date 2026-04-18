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

  def test_start_in_dynamic_section
    @input = "start.o"
    @output = "start"
    compile_path = Pathname.new("sample/C/start.c").to_s
    IO.popen(["gcc", "-fPIC", "-c", "-o", @input, "%s" % compile_path]).close

    Caotral::Linker.link!(inputs: [@input], output: @output, linker: "self", pie: true, needed: ["libc.so.6"], executable: false)

    elf = Caotral::Binary::ELF::Reader.read!(input: @output, debug: false)
    dynstr = elf.find_by_name(".dynstr")
    dynsym = elf.find_by_name(".dynsym")
    needed = elf.find_by_name(".dynamic").body.select(&:needed?)
    got_plt = elf.find_by_name(".dynamic").body.select(&:plt_got?)
    jmp_rel = elf.find_by_name(".dynamic").body.select(&:jmp_rel?)
    dynsym_names = dynsym.body.map(&:name_string)
    assert_equal(1, needed.size)
    assert_equal(dynstr.body.lookup(needed.first.un), "libc.so.6")
    assert_include(dynsym_names, "_exit")
    assert_include(dynsym_names, "_start")
    assert_equal(1, got_plt.size)
    assert_equal(1, jmp_rel.size)
  end

  def test_start_in_executable
    @input = "start.o"
    @output = "start"

    compile_path = Pathname.new("sample/C/start.c").to_s
    IO.popen(["gcc", "-fPIC", "-c", "-o", @input, "%s" % compile_path]).close

    Caotral::Linker.link!(inputs: [@input], output: @output, linker: "self", pie: true, needed: ["libc.so.6"], executable: true)

    io = IO.popen(["./#{@output}"])
    stdout = io.read
    io.close
    pid, exit_code = check_process($?.to_i)
    assert_equal("hello, world!!!\n", stdout)
    assert_equal(0, exit_code)
  end
end
