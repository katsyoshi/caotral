require "vaporware"

class VaporwareTest
  def initialize(file) = @vaporware = Vaporware::Compiler.new(file)

  def test_sample_plus
    @vaporware.compile
    IO.popen(["gcc", "-o", "tmp", "tmp.s"]).close
    IO.popen("./tmp").close
    p ($?.to_i >> 8) == 247
    File.delete("tmp.s")
    File.delete("tmp")
  end
end

VaporwareTest.new("sample/plus.rb").test_sample_plus
