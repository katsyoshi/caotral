require "caotral"
require "test/unit"
class Caotral::Linker::WriterTest < Test::Unit::TestCase
  def setup
    Caotral.assemble(input: "sample/assembler/plus.s", assembler: "self", output: "plus.o")
    @elf_obj = Caotral::Linker::Reader.read!(input: "plus.o", debug: false)
  end
  def teardown
    File.delete("plus.o") if File.exist?("plus.o")
    File.delete("written.o") if File.exist?("written.o")
  end
  def test_write
    written_output = Caotral::Linker::Writer.write!(elf_obj: @elf_obj, output: "written.o", debug: false)
    read_written_elf = Caotral::Linker::Reader.read!(input: written_output, debug: false)
    assert_equal @elf_obj.header.shoffset.pack("C*").unpack("Q<").first, read_written_elf.header.shoffset.pack("C*").unpack("Q<").first
    assert_equal @elf_obj.sections.size, read_written_elf.sections.size
  end
end
