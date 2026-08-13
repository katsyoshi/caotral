require_relative "../../../test_suite"

class Caotral::Linker::BSSTest < Test::Unit::TestCase
  include TestProcessHelper
  attr_reader :output, :inputs
  def teardown
    inputs.each { |input| File.delete(input) unless input.nil? }
    File.delete(output) if File.exist?(output)
  end
  def test_bss
    path = Pathname.new("sample/assembler/bss.s").to_s
    input = "bss.o"
    IO.popen(["as", "-o", input, path]).close
    @inputs = [input]
    @output = "bss"

    Caotral::Linker.link!(inputs:, output:, linker: "self")

    reader = Caotral::Binary::ELF::Reader.new(input: output, debug: false)
    elf = reader.read
    bss = elf.find_by_name(".bss")

    assert_equal(:nobits, bss.header.type)
    assert_equal(8, bss.header.size)

    IO.popen(["./#{@output}"]).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(42, exit_code)
    assert_equal(0, handle_code)
  end
end
