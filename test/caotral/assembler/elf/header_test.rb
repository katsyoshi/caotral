require "caotral"
require "test/unit"

class Caotral::Assembler::ELF::HeaderTest < Test::Unit::TestCase
  def setup = @elf_header = Caotral::Assembler::ELF::Header.new

  def test_build_elf_header
    # TODO: ELF Header Section binary
  end
end
