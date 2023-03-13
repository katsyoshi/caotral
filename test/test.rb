require "vaporware"

class VaporwareTest
  def initialize(file, debug = false)
    @vaporware = Vaporware::Compiler.new(file, debug:)
    @debug = debug
  end

  def test_sample_plus
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    puts [exit_code == 9, handle_code == 0].all?
    puts exit_code, handle_code if @debug
    File.delete("tmp") unless @debug
  end

  def test_sample_variable
    @vaporware.compile
    IO.popen("./tmp").close
    exit_code, handle_code = check_process($?.to_i)
    puts [exit_code == 1, handle_code == 0].all?
    puts exit_code, handle_code if @debug
    File.delete("tmp") unless @debug
  end

  private

  def check_process(pid)
    [
      pid >> 8, # process's exit code
      pid & 0x00FF # process's handled error code
    ]
  end
end

debug = ARGV.shift
VaporwareTest.new("sample/plus.rb", debug).test_sample_plus
VaporwareTest.new("sample/variable.rb", debug).test_sample_variable
