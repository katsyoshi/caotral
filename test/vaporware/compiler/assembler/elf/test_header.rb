require "vaporware"
require "test/unit"

class Vaporware::Compiler::Assembler::ELF::HeaderTest < Test::Unit::TestCase
  def setup = @elf_header = Vaporware::Compiler::Assembler::ELF::Header.new
  def test_filled_fields
    assert_equal(@elf_header.empties, [:@entry, :@phoffset, :@shoffset, :@shnum, :@shstrndx])
    @elf_header.set!(shoffset: 1)
    assert_equal(@elf_header.empties, [:@entry, :@phoffset, :@shnum, :@shstrndx])
  end

  def test_build_elf_header
    # TODO: ELF Header Section binary
  end
end
