require "vaporware"
require "test/unit"

class Vaporware::CompilerTest < Test::Unit::TestCase
  def setup = @generated = ["tmp.s", "tmp.o"]
  def teardown
    File.delete("tmp") if File.exist?("tmp")
    @generated.map { File.delete(_1) if File.exist?(_1) }
  end
  def test_sample_plus
    @file = "sample/plus.rb"
    @vaporware = Vaporware::Compiler.compile(@file, assembler: "self")
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(9, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_variable
    @file = "sample/variable.rb"
    @vaporware = Vaporware::Compiler.compile(@file, assembler: "self")
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_if
    @file = "sample/if.rb"
    @vaporware = Vaporware::Compiler.compile(@file, assembler: "self")
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_else
    @file = "sample/else.rb"
    @vaporware = Vaporware::Compiler.compile(@file, assembler: "self")
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(2, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_while
    @file = "sample/while.rb"
    @vaporware = Vaporware::Compiler.compile(@file)
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(55, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_call_method
    @generated = ["libtmp.so", "libtmp.so.o", "libtmp.so.s"]
    @file = "sample/method.rb"
    @vaporware = Vaporware::Compiler.compile(@file, dest: "./libtmp.so", shared: true)
    require './sample/fiddle.rb'
    assert_equal(10, X.aibo)
  end

  private

  def check_process(pid)
    [
      pid >> 8, # process's exit code
      pid & 0x00FF # process's handled error code
    ]
  end
end
