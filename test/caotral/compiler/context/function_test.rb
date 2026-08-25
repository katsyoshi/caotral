require_relative "../../../test_suite"

class Caotral::Compiler::Context::FunctionTest < Test::Unit::TestCase
  def test_context_function
    body = RubyVM::AbstractSyntaxTree.parse("")
    function = Caotral::Compiler::Context::Function.new(
      name: :foo,
      parameters: %i(a b c),
      locals: %i(z y z),
      body:
    )
    assert_equal(:foo, function.name)
    assert_equal(Set[:z, :y], function.locals)
    assert_equal([:a, :b, :c], function.parameters)
    assert_equal(body, function.body)
  end
end
