require "vaporware"

class VaporwareTest
  def initialize(file, debug = false) = @vaporware = Vaporware::Compiler.new(file, debug:)

  def test_sample_plus
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    puts [exit_code == 9, handle_code == 0].all?
    File.delete("tmp")
  end

  def test_sample_variable
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    puts exit_code
    puts handle_code
    File.delete("tmp")
  end

  private

  def check_process(pid)
    [
      pid >> 8, # process's exit code
      pid & 0x00FF # process's handled error code
    ]
  end
end

exit 1 unless [
  VaporwareTest.new("sample/plus.rb", true).test_sample_plus,
  VaporwareTest.new("sample/variable.rb", true).test_sample_variable,
].all?
