require "vaporware"
require "test/unit"
require "tempfile"

class Vaporware::Compiler::Assembler::ELFTest < Test::Unit::TestCase
  def reference_binary = ""

  def test_to_elf
    input = __dir__ + "/amd64.s"

    assembler = Vaporware::Compiler::Assembler.new(input:, output: "amd64.o")
    header, null, text, data, bss, note, symtab, strtab, shstrtab, *section_headers = assembler.to_elf
    sh_null, sh_text, sh_data, sh_bss, sh_note, shsymtab, sh_strtab, sh_shstrtab = section_headers
    r_header, r_null, r_text, r_data, r_bss, r_note, r_symtab, r_strtab, r_shstrtab, *r_section_headers = readelf
    r_sh_null, r_sh_text, r_sh_data, r_sh_bss, r_sh_note, * = r_section_headers
    assert_equal(r_header, header.unpack("C*"))
    assert_equal(r_null, null.unpack("C*"))
    assert_equal(r_data, data.unpack("C*"))
    # remove alignment bytes
    assert_equal(r_text, text.unpack("C*")[..-7])
    assert_equal(r_bss, bss.unpack("C*"))
    assert_equal(r_note, note.unpack("C*"))
    assert_equal(r_symtab, symtab.unpack("C*"))
    assert_equal(r_strtab, strtab.unpack("C*"))
    ref_shstrtab = r_shstrtab.pack("C*").split("\0").select { |str| str.size > 0 }.sort
    assert(ref_shstrtab.zip(shstrtab.split("\0").select { |str| str.size > 0 }.sort).all? { |ref, act| ref =~ /#{act}/ })
    assert_equal(r_sh_null, sh_null.unpack("C*"))
    assert_equal(r_sh_text, sh_text.unpack("C*"))
    assert_equal(r_sh_data, sh_data.unpack("C*"))
    assert_equal(r_sh_bss, sh_bss.unpack("C*"))
    assert_equal(r_sh_note, sh_note.unpack("C*"))
  end

  def readelf
    [
      [127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 62, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 64, 0, 8, 0, 7, 0], # elf header
      [], # null section
      [85, 72, 137, 229, 72, 131, 236, 0, 106, 1, 106, 2, 95, 88, 72, 1, 248, 80, 106, 3, 95, 88, 72, 15, 175, 199, 80, 106,5, 106, 4, 95, 88, 72, 41, 248, 80, 95, 88, 72, 153, 72, 247, 255, 80, 72, 137, 236, 93, 195], # text section
      [], # data section
      [], # bss section
      [4, 0, 0, 0, 32, 0, 0, 0, 5, 0, 0, 0, 71, 78, 85, 0, 2, 0, 1, 192, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 192, 4, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], # note section
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 16, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,0, 0, 0, 0, 0, 0, 0, 0, 0], # symtab section
      [0, 109, 97, 105, 110, 0], # strtab section 
      [0, 46, 115, 121, 109, 116, 97, 98, 0, 46, 115, 116, 114, 116, 97, 98, 0, 46, 115, 104, 115, 116, 114, 116, 97, 98, 0,46, 116, 101, 120, 116, 0, 46, 100, 97, 116, 97, 0, 46, 98, 115, 115, 0, 46, 110, 111, 116, 101, 46, 103, 110, 117, 46, 112, 114, 111, 112, 101, 114, 116, 121, 0], # shstrtab section
      # section headers 
      [0]*64, # null
      [1, 0, 0, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # text
      [7, 0, 0, 0, 1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 114, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # data
      [13, 0, 0, 0, 8, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 114, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # bss
      [18, 0, 0, 0, 7, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 120, 0, 0, 0, 0, 0, 0, 0, 48, 0, 0, 0, 0, 0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # note
      [],
    ]
  end
end
