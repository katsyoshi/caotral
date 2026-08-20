require "caotral"
require "test/unit"
require "open3"

module BuildFixtureHelper
  def fixture_command(*command)
    o, e, s = Open3.capture3(*command)
    return o if s.success?

    raise "command failed: #{command.join(" ")}\n#{e}"
  end

  def compile_fixture(output:, input:, options: []) = fixture_command("gcc", *options, "-S", "-o", output, input)
  def assemble_fixture(output:, input:) = fixture_command("as", "-o", output, input)
  def create_archive(output:, inputs:) = fixture_command("ar", "rcsD", output, *inputs)
end

module TestProcessHelper
  def check_process(status)
    exit_code = status >> 8
    handle_code = status & 0x7f
    [exit_code, handle_code]
  end
end
