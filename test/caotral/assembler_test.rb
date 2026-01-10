require "caotral"
require "test/unit"
require "tempfile"
require "pathname"

class Caotral::Assembler::ELFTest < Test::Unit::TestCase
  def test_to_elf
    input = Pathname.pwd.join('sample', 'assembler', 'plus.s').to_s
    output = "amd64.o"
    Caotral::Assembler.new(input:, output:).to_elf
    results = Caotral::Binary::ELF::Reader.new(input: output).read
    text = results.find_by_name(".text")
    symtab = results.find_by_name(".symtab")
    assert_equal(ref_text, text.body.unpack("C*"))
    assert_equal(ref_symtab, symtab.body.map(&:build).map { it.unpack("C*") }.flatten)
    File.delete("amd64.o")
  end

  def test_assembler_command
    input = Pathname.pwd.join('sample', 'assembler', 'plus.s').to_s
    assembler = Caotral::Assembler.new(input:, output: "amd64.o")
    assert_equal("as", assembler.command("as"))
    assert_equal("as", assembler.command("gcc"))
    assert_equal("clang", assembler.command("clang"))
    assert_match(/clang/, assembler.command("llvm"))
    assert_raise(Caotral::Assembler::Error) { assembler.command("foo") }
  end

  def ref_elf_header = [127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 62, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 64, 0, 8, 0, 7, 0]
  def ref_text = [85, 72, 137, 229, 72, 131, 236, 0, 106, 1, 106, 2, 95, 88, 72, 1, 248, 80, 106, 3, 95, 88, 72, 15, 175, 199, 80, 106,5, 106, 4, 95, 88, 72, 41, 248, 80, 95, 88, 72, 153, 72, 247, 255, 80, 72, 137, 236, 93, 72, 137, 199, 72, 199, 192, 60, 0, 0, 0, 15, 5]
  def ref_symtab = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 18, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,0, 0, 0, 0, 0, 0, 0, 0, 0]
  def dumped_references
    [
      [], # data section
      [], # bss section
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 78, 85, 76, 76, 0, 0, 0, 0],#
      # [4, 0, 0, 0, 32, 0, 0, 0, 5, 0, 0, 0, 71, 78, 85, 0, 2, 0, 1, 192, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 192, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], # note section
      
      [0, 109, 97, 105, 110, 0], # strtab section 
      [0, 46, 115, 121, 109, 116, 97, 98, 0, 46, 115, 116, 114, 116, 97, 98, 0, 46, 115, 104, 115, 116, 114, 116, 97, 98, 0,46, 116, 101, 120, 116, 0, 46, 100, 97, 116, 97, 0, 46, 98, 115, 115, 0, 46, 110, 111, 116, 101, 46, 103, 110, 117, 46, 112, 114, 111, 112, 101, 114, 116, 121, 0], # shstrtab section
      # section headers 
      [0]*64, # null
      [1, 0, 0, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 61, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # text
      [7, 0, 0, 0, 1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 125, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # data
      [13, 0, 0, 0, 8, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 125, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # bss
      [18, 0, 0, 0, 7, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # note
      [24, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 148, 0, 0, 0, 0, 0, 0, 0, 48, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 1, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 0], # symtab
      [32, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 196, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # strtab
      [40, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 202, 0, 0, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # shstrtab
      [],
    ]
  end
end
