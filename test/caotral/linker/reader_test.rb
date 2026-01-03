require "caotral"
require "test/unit"
class Caotral::Linker::ReaderTest < Test::Unit::TestCase
  def setup = Caotral.assemble(input: "sample/assembler/plus.s", output: "plus.o", assembler: "self")
  def teardown = File.delete("plus.o") if File.exist?("plus.o")
  def test_read
    elf_obj = Caotral::Linker::Reader.read!(input: "plus.o", debug: false)
    assert_equal elf_obj.header.shoffset.pack("C*").unpack("Q<").first, 264
    assert_equal elf_obj.sections.size, 8
    assert_equal elf_obj.sections[0].section_name, "null"
    shstrtab = elf_obj.sections[elf_obj.header.shstrndx]
    assert_equal shstrtab.section_name, ".shstrtab"
    assert_equal shstrtab.body.names, "\0.text\0.data\0.bss\0.note\0.symtab\0.strtab\0.shstrtab\0"
    assert_equal elf_obj.sections[1].section_name, ".text"
    assert_equal elf_obj.sections[1].header.size, 61
  end
end
