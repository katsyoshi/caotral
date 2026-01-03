require "caotral"
require "test/unit"
class Caotral::Linker::WriterTest < Test::Unit::TestCase
  def setup
    Caotral.assemble(input: "sample/assembler/plus.s", assembler: "self", output: "plus.o")
    @elf_obj = Caotral::Linker::Reader.read!(input: "plus.o", debug: false)
  end
  def teardown
    File.delete("plus.o") if File.exist?("plus.o")
    File.delete("write.o") if File.exist?("write.o")
    File.delete("write") if File.exist?("write")
    File.delete("relocatable.o") if File.exist?("relocatable.o")
    File.delete("relocated_exec") if File.exist?("relocated_exec")
  end
  def test_write
    written_output = Caotral::Linker::Writer.write!(elf_obj: @elf_obj, output: "write.o", debug: false)
    read_written_elf = Caotral::Linker::Reader.read!(input: written_output, debug: false)
    assert_equal @elf_obj.header.shoffset.pack("C*").unpack("Q<").first, read_written_elf.header.shoffset.pack("C*").unpack("Q<").first
    assert_equal 4, read_written_elf.sections.size
    assert_equal 0x401000, read_written_elf.header.entry.pack("C*").unpack("Q<").first
  end

  def test_execute_written
    written_output = Caotral::Linker::Writer.write!(elf_obj: @elf_obj, output: "write", debug: false)
    File.chmod(0755, "./write")
    IO.popen("./write").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(9, exit_code)
    assert_equal(0, handle_code)
  end

  def test_relocation_write_and_execute
    IO.popen("gcc -c -fno-pic -fno-pie -o relocatable.o sample/C/rel_text.c").close
    elf_obj = Caotral::Linker::Reader.read!(input: "relocatable.o", debug: false)
    Caotral::Linker::Writer.write!(elf_obj:, output: "relocated_exec", debug: false)
    File.chmod(0755, "./relocated_exec")
    IO.popen("./relocated_exec").close
    exit_code, _handle_code = check_process($?.to_i)
    assert_equal(0, exit_code)
  end

  private
  def check_process(status)
    exit_code = status >> 8
    handle_code = status & 0x7f
    [exit_code, handle_code]
  end
end
