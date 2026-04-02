require_relative "../../test_suite"

class LinkerNeededTest < Test::Unit::TestCase
  def test_needed_options
    compile_path = Pathname.new("sample/C/needed.c").to_s
    IO.popen(["gcc", "-fPIE", "-c", "-o", "needed.o", "%s" % compile_path]).close

    linker = Caotral::Linker.new(inputs: ["needed.o"], linker: "self", pie: true, needed: ["libc.so.6"])
    assert_equal ["libc.so.6"], linker.instance_variable_get(:@needed)
  end
end
