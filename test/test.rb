require "vaporware"

class VaporwareTest
  def initialize(file) = @vaporware = Vaporware::Compiler.new(file)

  def test_sample_plus
    @vaporware.compile
    IO.popen("./tmp").close
    p ($?.to_i >> 8) == 9
    File.delete("tmp")
  end
end

VaporwareTest.new("sample/plus.rb").test_sample_plus
