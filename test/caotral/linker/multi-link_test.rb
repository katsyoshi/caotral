require_relative "../../test_suite"

class Caotral::Linker::MultiFileLinkingTest < Test::Unit::TestCase
  include TestProcessHelper

  def setup
    @outputs = ["a.o", "b.o", "multifile"].freeze
    @inputs = ["a", "b"].freeze
  end

  def teardown
    # @outputs.each { |output| File.delete(output) if File.exist?(output) }
  end

  def test_link_multi_files
    inputs = []
    output = @outputs.last
    @inputs.each do |x|
      path = Pathname.new("sample/C/multi-file-link-#{x}.c").to_s
      o = "%s.o" % x
      IO.popen(["gcc", "-o", o, "-c", "%s" % path]).close
      inputs << o
    end
    Caotral::Linker.link!(inputs:, output:, linker: "self")
    File.chmod(0755, "./#{output}")
    IO.popen("./#{output}").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(exit_code, 42)
    assert_equal(handle_code, 0)
  end
end
