require "caotral"
require "test/unit"

class Caotral::LinkerTest < Test::Unit::TestCase
  def test_librarie
    linker = Caotral::Linker.new(input: "tmp.o")
    assert_false(linker.libpath.empty?, "should not be empty")
    assert_false(linker.gcc_libpath.empty?, "should not be empty")
  end

  def test_link_command
    linker = Caotral::Linker.new(input: "tmp.o", output: "tmp")
    assert_match(%r|mold -o tmp -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 /.+/crt1.o /.+/crti.o /.+/crtbegin.o /.+/crtend.o /.+/libc.so /.+/crtn.o tmp.o|, linker.link_command)
    linker = Caotral::Linker.new(input: "tmp.o", output: "tmp", shared: true)
    assert_match(%r|mold -o tmp -m elf_x86_64 --shared /.+/crti.o /.+/crtbeginS.o /.+/crtendS.o /.+/libc.so /.+/crtn.o tmp.o|, linker.link_command)
  end
end
