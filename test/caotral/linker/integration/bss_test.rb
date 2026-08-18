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

  def test_initialize_zero_bss
    path = Pathname.new("sample/assembler/bss_initialize_zero.s").to_s
    input = "bss.o"
    IO.popen(["as", "-o", input, path]).close
    @inputs = [input]
    @output = "bss"

    Caotral::Linker.link!(inputs:, output:, linker: "self")

    reader = Caotral::Binary::ELF::Reader.new(input: output, debug: false)
    elf = reader.read
    bss = elf.find_by_name(".bss")

    assert_equal(:nobits, bss.header.type)
    assert_equal(32, bss.header.size)

    IO.popen(["./#{@output}"]).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(42, exit_code)
    assert_equal(0, handle_code)
  end

  def test_initialize_zero_pie_bss
    path = Pathname.new("sample/assembler/bss_initialize_zero.s").to_s
    input = "bss.o"
    IO.popen(["as", "-o", input, path]).close
    @inputs = [input]
    @output = "bss"

    Caotral::Linker.link!(inputs:, output:, linker: "self", pie: true)

    reader = Caotral::Binary::ELF::Reader.new(input: output, debug: false)
    elf = reader.read
    bss = elf.find_by_name(".bss")
    dynamic_symbol = elf.find_by_name(".dynsym").find_defined_symbol("value")

    assert_equal(elf.index(".bss"), dynamic_symbol.shndx)
    assert_equal(:nobits, bss.header.type)
    assert_equal(32, bss.header.size)
    assert_equal(bss.header.addr + 24, dynamic_symbol.value)

    IO.popen(["./#{@output}"]).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(42, exit_code)
    assert_equal(0, handle_code)
  end

  def test_multiple_bss
    @inputs = []
    [
      [Pathname.new("sample/assembler/bss.s").to_s, "bss.o"],
      [Pathname.new("sample/assembler/two_bss_sections.s").to_s, "two_bss_section.o"],
    ].each do |(path, input)|
      IO.popen(["as", "-o", input, path]).close
      @inputs << input
    end
    @output = "bss"

    Caotral::Linker.link!(inputs:, output:, linker: "self", pie: true)

    reader = Caotral::Binary::ELF::Reader.new(input: output, debug: false)
    elf = reader.read
    bss = elf.find_by_name(".bss")
    aligned_symbol = elf.find_by_name(".symtab").find_defined_symbol("aligned_value")

    assert_equal(elf.index(".bss"), aligned_symbol.shndx)
    assert_equal(32, bss.header.size)
    assert_equal(16, bss.header.addralign)
    assert_equal(16, aligned_symbol.value)

    IO.popen(["./#{@output}"]).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(42, exit_code)
    assert_equal(0, handle_code)
  end

  def test_zero_size_bss
    @inputs = []
    [
      [Pathname.new("sample/assembler/empty_bss.s").to_s, "bss.o"],
    ].each do |(path, input)|
      IO.popen(["as", "-o", input, path]).close
      @inputs << input
    end
    @output = "bss"

    Caotral::Linker.link!(inputs:, output:, linker: "self")

    reader = Caotral::Binary::ELF::Reader.new(input: output, debug: false)
    elf = reader.read
    bss = elf.find_by_name(".bss")
    symbol = elf.find_by_name(".symtab").find_defined_symbol("value")

    assert_not_nil(bss)
    assert_equal(elf.index(".bss"), symbol.shndx)
    assert_equal(0, bss.header.size)
    assert_equal(8, bss.header.addralign)
    assert_equal(0, symbol.value)
  end
end
