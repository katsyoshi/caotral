require_relative "../../../test_suite"

class Caotral::Linker::ArchiveTest < Test::Unit::TestCase
  include CommonSetupHelper
  include BuildFixtureHelper
  include TestProcessHelper

  def test_integrate_archive_file
    @output = "archive"
    output = "archive.a"
    @generated << @output
    @generated << output
    inputs = [
      "sample/C/multi-file-link-a.c",
      "sample/C/add.c"
    ]
    create_archive(output:, inputs:, options: ["-fno-pie"])
    create_object(output: "multi-file-link-b.o", input: "sample/C/multi-file-link-b.c")
    @inputs << "multi-file-link-b.o"
    archives = [output]
    Caotral::Linker.link!(output: @output, inputs: @inputs, archives:, linker: "self")
    _stdout, stderr, status = Open3.capture3("./#{@output}")
    assert_equal(42, status.exitstatus, stderr)
  end

  def test_extract_dependent_archive_member
    @output = "recursive-archive"
    output = "recursive-archive.a"
    @generated << @output
    @generated << output
    inputs = [
      "sample/C/archive-recursive.c",
      "sample/C/add.c"
    ]
    create_archive(output:, inputs:, options: ["-fno-pie"])
    create_object(output: "multi-file-link-b.o", input: "sample/C/multi-file-link-b.c")
    @inputs << "multi-file-link-b.o"
    archives = [output]
    Caotral::Linker.link!(output: @output, inputs: @inputs, archives:, linker: "self")
    _stdout, stderr, status = Open3.capture3("./#{@output}")
    assert_equal(42, status.exitstatus, stderr)
  end
end
