require_relative "../../../test_suite"

class Caotral::Linker::AlignmentTest < Test::Unit::TestCase
  include TestProcessHelper

  def setup
    @inputs = ["alignment_prefix_integration.o", "aligned_sections_integration.o"]
    @output = "alignment_integration"
  end

  def teardown
    [*@inputs, @output].each do |path|
      File.delete(path) if File.exist?(path)
    end
  end

  def test_aligned_contributions_execute
    fixtures = [
      "sample/assembler/alignment_prefix.s",
      "sample/assembler/aligned_sections.s",
    ]
    @inputs.zip(fixtures).each do |input, fixture|
      IO.popen(["as", "-o", input, fixture]).close
    end

    Caotral::Linker.link!(inputs: @inputs, output: @output, linker: "self")

    elf = Caotral::Binary::ELF::Reader.read!(input: @output)
    symtab = elf.find_by_name(".symtab")
    {
      ".text" => "aligned_function",
      ".rodata" => "aligned_rodata",
      ".data" => "aligned_data",
    }.each do |section_name, symbol_name|
      section = elf.find_by_name(section_name)
      symbol = symtab.find_defined_symbol(symbol_name)

      assert_equal(32, section.header.addralign)
      assert_equal(0, (section.header.addr + symbol.value) % 32)
    end

    _stdout, _stderr, status = Open3.capture3("./#{@output}")
    exit_code, handle_code = check_process(status.to_i)
    assert_equal(42, exit_code)
    assert_equal(0, handle_code)
  end
end
