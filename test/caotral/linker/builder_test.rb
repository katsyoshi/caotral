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

    symtab = elf.find_by_name(".symtab").body
    aligned_function = symtab.find { |sym| sym.name_string == "aligned_function" && sym.shndx != 0 }
    aligned_rodata = symtab.find { |sym| sym.name_string == "aligned_rodata" && sym.shndx != 0 }
    aligned_data = symtab.find { |sym| sym.name_string == "aligned_data" && sym.shndx != 0 }

    assert_equal(32, aligned_function.value)
    assert_equal(32, aligned_rodata.value)
    assert_equal(32, aligned_data.value)
  end
end
