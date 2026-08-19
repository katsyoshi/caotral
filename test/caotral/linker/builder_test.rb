require_relative "../../test_suite"

class Caotral::Linker::BuilderTest < Test::Unit::TestCase
  attr_reader :inputs, :output, :elf_objs
  def setup
    @inputs = []
    @elf_objs = []
  end
  def teardown = inputs.each { |i| File.delete(i) if File.exist?(i) }

  def test_build_alignment
    [
      ["sample/assembler/alignment_prefix.s", "alignment_prefix.o"],
      ["sample/assembler/aligned_sections.s", "aligned_sections.o"],
    ].each do |(path, input)|
      IO.popen(["as", "-o", input, path]).close
      @elf_objs << Caotral::Binary::ELF::Reader.read!(input:)
      @inputs << input
    end

    builder = Caotral::Linker::Builder.new(elf_objs:)
    elf = builder.build
    text = elf.find_by_name(".text")
    rodata = elf.find_by_name(".rodata")
    data = elf.find_by_name(".data")

    assert_equal(32, text.header.addralign)
    assert_equal(32, rodata.header.addralign)
    assert_equal(32, data.header.addralign)

    assert_equal([0x90] * 9, text.body.byteslice(23, 9).bytes)
    assert_equal([0x00] * 31, rodata.body.byteslice(1, 31).bytes)
    assert_equal([0x00] * 31, data.body.byteslice(1, 31).bytes)

    symtab = elf.find_by_name(".symtab")
    aligned_function = symtab.find_defined_symbol("aligned_function")
    aligned_rodata = symtab.find_defined_symbol("aligned_rodata")
    aligned_data = symtab.find_defined_symbol("aligned_data")

    assert_equal(32, aligned_function.value)
    assert_equal(32, aligned_rodata.value)
    assert_equal(32, aligned_data.value)
  end

  def test_align_first_text_contribution_after_synthetic_start
    [
      ["sample/assembler/aligned_sections.s", "aligned_sections_first.o"],
      ["sample/assembler/alignment_prefix.s", "alignment_prefix_second.o"],
    ].each do |(path, input)|
      IO.popen(["as", "-o", input, path]).close
      @elf_objs << Caotral::Binary::ELF::Reader.read!(input:)
      @inputs << input
    end

    builder = Caotral::Linker::Builder.new(elf_objs:)
    elf = builder.build
    text = elf.find_by_name(".text")
    symtab = elf.find_by_name(".symtab")
    aligned_function = symtab.find_defined_symbol("aligned_function")

    assert_equal([0x90] * 15, text.body.byteslice(17, 15).bytes)
    assert_equal(32, aligned_function.value)
  end

  def test_align_data_relocation_offset
    [
      ["sample/assembler/alignment_prefix.s", "alignment_prefix_relocation.o"],
      ["sample/assembler/aligned_data_relocation.s", "aligned_data_relocation.o"],
    ].each do |(path, input)|
      IO.popen(["as", "-o", input, path]).close
      @elf_objs << Caotral::Binary::ELF::Reader.read!(input:)
      @inputs << input
    end

    builder = Caotral::Linker::Builder.new(elf_objs:, executable: false)
    elf = builder.build
    symtab = elf.find_by_name(".symtab")
    symbol = symtab.find_defined_symbol("aligned_data_reference")
    relocation = elf.find_by_name(".rela.data").body.first

    assert_equal(32, symbol.value)
    assert_equal(symbol.value, relocation.offset)
  end

  def test_undefined_start_uses_synthetic_start
    input = "undefined_start.o"
    IO.popen(["as", "-o", input, "sample/assembler/undefined_start.s"]).close
    input_elf = Caotral::Binary::ELF::Reader.read!(input:)
    @elf_objs << input_elf
    @inputs << input

    input_start = input_elf.find_by_name(".symtab").body.find do |symbol|
      symbol.name_string == "_start"
    end

    assert_equal(0, input_start.shndx)
    assert_false(input_elf.entry_start?)

    elf = Caotral::Linker::Builder.new(elf_objs:).build
    text = elf.find_by_name(".text")
    main = elf.find_by_name(".symtab").find_defined_symbol("main")

    assert_equal(17, main.value)
    assert_equal(main.value - 5, text.body.byteslice(1, 4).unpack1("l<"))
  end
end
