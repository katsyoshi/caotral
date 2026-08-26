require_relative "../../test_suite"

class Caotral::Compiler::AnalyzerTest < Test::Unit::TestCase
  def test_analyze_methods_and_local_variables
    code = File.read("sample/method_and_variable.rb")
    ast = RubyVM::AbstractSyntaxTree.parse(code)
    context = Caotral::Compiler::Analyzer.analyze(ast)
    entry = context.entry
    last_node = ast.children.last

    assert_not_nil(entry)
    assert_nil(entry.name)
    assert_equal(1, entry.locals.size)
    assert_equal(Set[:a], entry.locals)
    assert_equal(last_node.type, entry.body.type)
    assert_equal(last_node.first_lineno, entry.body.first_lineno)
    assert_equal(last_node.first_column, entry.body.first_column)
    assert_equal(last_node.last_lineno, entry.body.last_lineno)
    assert_equal(last_node.last_column, entry.body.last_column)
    assert_equal(Set[:foo], context.discovered_methods)
  end
end
