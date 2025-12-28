require "caotral"
require "test/unit"
class Caotral::Linker::ReaderTest < Test::Unit::TestCase
  def setup = Caotral.assemble(input: "sample/assembler/plus.s", output: "plus.o", assembler: "self")
  def teardown = File.delete("plus.o") if File.exist?("plus.o")
  def test_read
    elf_obj = Caotral::Linker::Reader.read!(input: "plus.o", debug: false)
    assert_equal elf_obj.header.shoffset.pack("C*").unpack("Q<").first, 256
  end
end
