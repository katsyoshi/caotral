require "caotral"
require "test/unit"
require "pathname"

class Caotral::Assembler::WriterTest < Test::Unit::TestCase
  def test_write
    input = Pathname.pwd.join('sample', 'assembler', 'plus.s').to_s
    output = "amd64.o"
    instructions = Caotral::Assembler::Reader.new(input:).read
    elf_obj = Caotral::Assembler::Builder.new(instructions:).build
    writer = Caotral::Assembler::Writer.new(elf_obj:, output:).write
    results = Caotral::Binary::ELF::Reader.new(input: output).read
    shstrtab = results.find_by_name(".shstrtab")
    text = results.find_by_name(".text")
    names = shstrtab.body.names
    assert_include(names, ".text")
    assert_include(names, ".strtab")
    assert_include(names, ".symtab")
    assert_include(names, ".shstrtab")
    assert_equal(text.body.unpack("C*"), ref_text)
  end
  def ref_text = [85, 72, 137, 229, 72, 131, 236, 0, 106, 1, 106, 2, 95, 88, 72, 1, 248, 80, 106, 3, 95, 88, 72, 15, 175, 199, 80, 106,5, 106, 4, 95, 88, 72, 41, 248, 80, 95, 88, 72, 153, 72, 247, 255, 80, 72, 137, 236, 93, 72, 137, 199, 72, 199, 192, 60, 0, 0, 0, 15, 5]
end
