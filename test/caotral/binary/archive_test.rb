require_relative "../../test_suite"

class Caotral::Binary::ArchiveTest < Test::Unit::TestCase
  include BuildFixtureHelper

  attr_reader :output, :inputs

  def teardown
    @inputs.each { |name| File.delete(name) }
    File.delete(output)
  end

  def test_archive
    @output = "archive.a"
    @inputs = []
    [
      "sample/C/multi-file-link-a.c",
      "sample/C/add.c"
    ].each do |input|
      output = File.basename(input, ".c") + ".s"
      compile_fixture(output:, input:, options: ["-fno-pie"])
      input = output
      asm = output
      output = File.basename(input, ".s") + ".o"
      assemble_fixture(output:, input:)
      File.delete(asm)
      @inputs << output
    end

    create_archive(output:, inputs:)
    archive = Caotral::Binary::Archive::Reader.new(output)
    archive.read!
  end 
end
