require_relative "../../test_suite"

class Caotral::Linker::GOTPCRelTest < Test::Unit::TestCase
  include TestProcessHelper
  def setup
    @generated = []
  end

  def teardown
    @generated.each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  def test_raise_error_for_unsupported_gotpcrel
    @generated.concat(["libtmp.so", "libtmp.so.o"])
    file = "sample/C/gotpcrel-call.c"
    IO.popen(["gcc", "-fno-plt", "-c", file, "-o", "libtmp.so.o"]).close

    err = assert_raise(Caotral::Binary::ELF::Error) do
      Caotral::Linker.link!(inputs: ["libtmp.so.o"], output: "libtmp.so", linker: "self", pie: true)
    end
    assert_match(/GOTPCREL|R_X86_64_GOTPCREL/, err.message)
  end
end
