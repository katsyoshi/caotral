require_relative "../../test_suite"

class Caotral::Compiler::AnalyzerTest < Test::Unit::TestCase
  def test_analyze_methods_and_local_variables
    code = File.read("sample/method_and_variable.rb")
    ast = RubyVM::AbstractSyntaxTree.parse(code)
    context = Caotral::Compiler::Analyzer.analyze(ast)
    assert_equal(1, context.local_variables.size)
    assert_equal(Set[:a], context.local_variables)
    assert_equal(Set[:foo], context.discovered_methods)
  end
end
