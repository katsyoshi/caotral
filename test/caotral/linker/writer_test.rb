require "caotral"
require "test/unit"
class Caotral::Linker::WriterTest < Test::Unit::TestCase
  def setup
    Caotral.assemble(input: "sample/assembler/plus.s", assembler: "self", output: "plus.o")
    elf_obj = Caotral::Binary::ELF::Reader.read!(input: "plus.o", debug: false)
    builder = Caotral::Linker::Builder.new(elf_objs: [elf_obj], debug: false)
    builder.resolve_symbols!
    @elf_obj = builder.build
    metadata = builder.linker_metadata
    Caotral::Linker::Layout.new(elf: @elf_obj, shared: false, pie: false, executable: true).apply!
    Caotral::Linker::Finalizer.new(elf: @elf_obj, metadata:, shared: false, pie: false, executable: true, debug: false).apply!
  end
  def teardown
    File.delete("plus.o") if File.exist?("plus.o")
    File.delete("write.o") if File.exist?("write.o")
    File.delete("write") if File.exist?("write")
    File.delete("relocatable.o") if File.exist?("relocatable.o")
    File.delete("relocated_exec") if File.exist?("relocated_exec")
    File.delete("output") if File.exist?("output")
  end
  def test_write
    written_output = Caotral::Linker::Writer.write!(elf_obj: @elf_obj, output: "write.o")
    read_written_elf = Caotral::Binary::ELF::Reader.read!(input: written_output, debug: false)
    assert_equal @elf_obj.header.shoffset, read_written_elf.header.shoffset
    assert_equal 7, read_written_elf.sections.size
    assert_equal 0x401000, read_written_elf.header.entry
  end

  def test_execute_written
    Caotral::Linker::Writer.write!(elf_obj: @elf_obj, output: "write")
    File.chmod(0755, "./write")
    IO.popen("./write").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(9, exit_code)
    assert_equal(0, handle_code)
  end

  def test_relocation_write_and_execute
    IO.popen("gcc -c -fno-pic -fno-pie -o relocatable.o sample/C/rel_text.c").close
    input_elf = Caotral::Binary::ELF::Reader.read!(input: "relocatable.o", debug: false)
    builder = Caotral::Linker::Builder.new(elf_objs: [input_elf], debug: false)
    builder.resolve_symbols!
    elf = builder.build
    metadata = builder.linker_metadata
    Caotral::Linker::Layout.new(elf:, shared: false, pie: false, executable: true).apply!
    Caotral::Linker::Finalizer.new(elf:, metadata:, shared: false, pie: false, executable: true, debug: false).apply!
    Caotral::Linker::Writer.write!(elf_obj: elf, output: "relocated_exec")
    File.chmod(0755, "./relocated_exec")
    IO.popen("./relocated_exec").close
    exit_code, _handle_code = check_process($?.to_i)
    assert_equal(0, exit_code)
  end

  def test_writer_do_not_mutate_finalized_elf
    before_elf_sections = snapshot(@elf_obj)
    output = "output"
    Caotral::Linker::Writer.new(elf_obj: @elf_obj, output:).write
    assert_equal(before_elf_sections, snapshot(@elf_obj))
  end

  private
  def check_process(status)
    exit_code = status >> 8
    handle_code = status & 0x7f
    [exit_code, handle_code]
  end
  def snapshot(elf)
    {
      header: elf.header.build,
      program_header: elf.program_headers.map(&:build),
      sections: elf.sections.map { |s| [s.section_name, s.header.build, s.build] }
    }
  end
end
