require_relative "../../test_suite"

class Caotral::Compiler::GenratorTest < Test::Unit::TestCase
  def output = "test_generated.s"
  def teardown = (File.delete(output) if File.exist?(output))
  def test_compile_executable_ruby_file
    Caotral::Compiler::Generator.new(input: "sample/plus.rb", output:).compile
    asm = File.read(output)
    assert_match(/main\:/, asm)
    assert_match(/.globl main/, asm)
  end

  def test_compile_non_executable_ruby_file_with_class
    Caotral::Compiler::Generator.new(input: "sample/klass.rb", output:).compile
    asm = File.read(output)
    assert_match("Init_test_generated:", asm)
    assert_match(".asciz \"Klass\"", asm)
  end

  def test_compile_non_executable_ruby_file_with_function
    Caotral::Compiler::Generator.new(input: "sample/method.rb", output:).compile
    asm = File.read(output)
    assert_match("aibo:", asm)
    assert_match("bibo:", asm)
  end

  def test_compile_executable_ruby_file_with_function
    Caotral::Compiler::Generator.new(input: "sample/main_with_method.rb", output:).compile
    asm = File.read(output)
    assert_match("aibo:", asm)
    assert_match("bibo:", asm)
    assert_match("main:", asm)
  end
end
