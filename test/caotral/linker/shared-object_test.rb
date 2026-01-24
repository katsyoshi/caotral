require_relative "../../test_suite"

class Caotral::Linker::SharedObjectLinkingTest < Test::Unit::TestCase
  include TestProcessHelper
  def setup
    @inputs = ["shared.o"]
    @output = "libshared.so"
    path = Pathname.new("sample/C/shared-object.c").to_s
    IO.popen(["gcc", "-fPIC", "-c", "-o", @inputs[0], "%s" % path]).close
  end

  def teardown
    File.delete(@inputs[0]) if File.exist?(@inputs[0])
    File.delete(@output) if File.exist?(@output)
  end

  def test_link_shared_object
    Caotral::Linker.link!(inputs: @inputs, output: @output, linker: "self", shared: true, executable: false)
    elf = Caotral::Binary::ELF::Reader.read!(input: @output, debug: false)
    assert_equal(:DYN, elf.header.type)
    assert_equal(:AMD64, elf.header.arch)
  end
end
