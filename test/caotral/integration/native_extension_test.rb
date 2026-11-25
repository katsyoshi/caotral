require_relative "../../test_suite"

class Caotral::IntegrationNativeExtensionTest < Test::Unit::TestCase
  include TestProcessHelper

  def setup = setup_ruby_box
  def teardown = teardown_native_binary

  def test_integration_for_ruby_box
    assembly = "libklass.s"
    object = "libklass.o"
    library = "libklass.so"
    @generated.concat([assembly, object, library])

    Caotral::Compiler::Generator.new(input: "sample/klass.rb", output: assembly, shared: true).compile

    _stdout, stderr, status = Open3.capture3("as", "-o", object, assembly)
    assert_equal(0, status.exitstatus, stderr)

    _stdout, stderr, status = Open3.capture3("mold", "--shared", "-o", library, object)
    assert_equal(0, status.exitstatus, stderr)

    box = Ruby::Box.new
    box.require "./libklass"

    assert_kind_of(Class, box::Klass)
    v = Object.new
    assert_same(v, box::Klass.new.identity(v))
  end
end
