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
    IO.popen("./#{@output}").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(42, exit_code)
    assert_equal(0, handle_code)
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
    IO.popen("./#{@output}").close
    exit_code, handle_code = check_process($?.to_i)
    assert_equal(42, exit_code)
    assert_equal(0, handle_code)
  end
end
