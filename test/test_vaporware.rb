require "vaporware"
require "test/unit"

class VaporwareTest < Test::Unit::TestCase
  def teardown = File.delete("tmp")

  def test_sample_plus
    @file = "sample/plus.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(9, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_variable
    @file = "sample/variable.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_if
    @file = "sample/if.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
  end

  private

  def check_process(pid)
    [
      pid >> 8, # process's exit code
      pid & 0x00FF # process's handled error code
    ]
  end
end
