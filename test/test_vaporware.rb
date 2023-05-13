require "vaporware"
require "test/unit"

class VaporwareTest < Test::Unit::TestCase
  def test_sample_plus
    @file = "sample/plus.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(9, exit_code)
    assert_equal(0, handle_code)
    File.delete("tmp")
  end

  def test_sample_variable
    @file = "sample/variable.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
    File.delete("tmp")
  end

  def test_sample_if
    @file = "sample/if.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
    File.delete("tmp")
  end

  def test_sample_else
    @file = "sample/else.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(2, exit_code)
    assert_equal(0, handle_code)
    File.delete("tmp")
  end

  def test_sample_while
    @file = "sample/while.rb"
    @vaporware = Vaporware::Compiler.new(@file)
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(55, exit_code)
    assert_equal(0, handle_code)
    File.delete("tmp")
  end

  def test_sample_call_method
    @file = "sample/method.rb"
    @vaporware = Vaporware::Compiler.new(@file, shared: true)
    @vaporware.compile
    require './sample/fiddle.rb'
    assert_equal(10, X.aibo)
    File.delete("libtmp.so")
  end

  private

  def check_process(pid)
    [
      pid >> 8, # process's exit code
      pid & 0x00FF # process's handled error code
    ]
  end
end
