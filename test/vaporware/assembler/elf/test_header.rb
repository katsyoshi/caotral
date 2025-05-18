require "vaporware"
require "test/unit"

class Vaporware::Assembler::ELF::HeaderTest < Test::Unit::TestCase
  def setup = @elf_header = Vaporware::Assembler::ELF::Header.new

  def test_build_elf_header
    # TODO: ELF Header Section binary
  end
end
