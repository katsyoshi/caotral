require "fiddle"
require_relative "../test_suite"

class Caotral::CompilerTest < Test::Unit::TestCase
  include CommonSetupHelper
  include TestProcessHelper

  def setup
    super
    @generated.concat(["tmp.s", "tmp.o", "tmp"])
    @output = "./tmp"
  end
  def test_sample_plus
    @file = "sample/plus.rb"
    @caotral = Caotral.compile!(input: @file, assembler: "self", linker: "self")
    File.chmod(755, @output)
    IO.popen(@output).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(9, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_variable
    @file = "sample/variable.rb"
    @caotral = Caotral.compile!(input: @file, assembler: "self", linker: "self")
    File.chmod(755, @output)
    IO.popen(@output).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_if
    @file = "sample/if.rb"
    @caotral = Caotral.compile!(input: @file)
    IO.popen(@output).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(1, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_else
    @file = "sample/else.rb"
    @caotral = Caotral.compile!(input: @file)
    IO.popen(@output).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(2, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_while
    @file = "sample/while.rb"
    @caotral = Caotral.compile!(input: @file)
    IO.popen(@output).close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(55, exit_code)
    assert_equal(0, handle_code)
  end

  def test_sample_call_method
    @generated = ["libtmp.so", "libtmp.so.o", "libtmp.so.s"]
    @file = "sample/method.rb"
    @output = "./libtmp.so"
    @caotral = Caotral.compile!(input: @file, output: @output, shared: true, linker: "mold", assembler: "as")
    require './sample/fiddle.rb'
    assert_equal(10, X.aibo)
  end

  def test_sample_call_method_with_arguments
    @generated = ["libargs.so", "libargs.so.o", "libargs.so.s"]
    @file = "sample/args_and_local_variables.rb"
    @output = "./libargs.so"
    @caotral = Caotral.compile!(input: @file, output: @output, shared: true, linker: "mold", assembler: "as")
    handle = Fiddle.dlopen(@output)
    foo = Fiddle::Function.new(
      handle["foo"],
      [Fiddle::TYPE_LONG, Fiddle::TYPE_LONG],
      Fiddle::TYPE_LONG
    )
    assert_equal(42, foo.call(40, 2))
  end

  def test_sample_method_if_without_else_continues
    @generated = ["libif.so", "libif.so.o", "libif.so.s"]
    @file = "sample/not_early_return.rb"
    @output = "./libif.so"
    @caotral = Caotral.compile!(input: @file, output: @output, shared: true, linker: "mold", assembler: "as")
    handle = Fiddle.dlopen(@output)
    not_early_if = Fiddle::Function.new(
      handle["not_early_return_if"],
      [Fiddle::TYPE_LONG],
      Fiddle::TYPE_LONG
    )

    assert_equal(42, not_early_if.call(1))
    assert_equal(42, not_early_if.call(9))
  end

  def test_rejects_more_than_six_required_positional_arguments
    @file = "sample/max_arguments.rb"
    error = assert_raise(NotImplementedError) do
      Caotral.compile!(input: @file, output: @output, shared: true, linker: "mold", assembler: "as")
    end
    assert_equal(
      "max_args has 7 required positional arguments; maximum supported is 6",
      error.message
    )
  end

  def test_sample_return_value_with_local_variable
    @generated = ["libtla.so", "libtla.so.o", "libtla.so.s"]
    @file = "sample/trailing_local_assignment.rb"
    @output = "./libtla.so"
    @caotral = Caotral.compile!(input: @file, output: @output, shared: true, linker: "mold", assembler: "as")
    handle = Fiddle.dlopen(@output)
    tla = Fiddle::Function.new(
      handle["trailing_local_assignment"],
      [Fiddle::TYPE_LONG],
      Fiddle::TYPE_LONG
    )

    assert_equal(42, tla.call(41))
  end
end
