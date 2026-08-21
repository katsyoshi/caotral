require_relative "../../test_suite"

class Caotral::Binary::ArchiveTest < Test::Unit::TestCase
  include BuildFixtureHelper

  attr_reader :output, :inputs

  def teardown = @garbage_box.each { |name| File.delete(name) if File.exist?(name) }

  def test_archive
    @output = "archive.a"
    @garbage_box = [@output]
    @inputs = []
    [
      "sample/C/multi-file-link-a.c",
      "sample/C/add.c"
    ].each do |input|
      output = File.basename(input, ".c") + ".s"
      @garbage_box << output
      compile_fixture(output:, input:, options: ["-fno-pie"])
      input = output
      output = File.basename(input, ".s") + ".o"
      @garbage_box << output
      assemble_fixture(output:, input:)
      @inputs << output
    end

    create_archive(output:, inputs:)
    reader = Caotral::Binary::Archive::Reader.new(output)
    reader.read!
    archive = reader.archive
    mul = archive.members.first
    add = archive.members.last
    symbol_tables = archive.symbol_tables
    name_table = archive.name_table
    assert_equal(2, archive.members.size)
    assert_equal("multi-file-link-a.o", mul.name)
    assert_equal("add.o", add.name)

    assert_equal(1, symbol_tables.size)
    assert_equal("foo", symbol_tables.first.symbols.first.name)
    assert_equal(170, symbol_tables.first.symbols.first.offset)
    assert_not_nil(name_table)
    assert_equal(["multi-file-link-a.o"], name_table.names)
    assert_equal("multi-file-link-a.o", name_table.resolve(0))
  end
end
