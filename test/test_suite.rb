require "caotral"
require "test/unit"
require "open3"

module CommonSetupHelper
  attr_reader :generated, :inputs, :output

  def setup = (@generated, @inputs, @output = [], [], nil)
  def teardown = @generated.each { |f| File.delete(f) if File.exist?(f) }
end

module BuildFixtureHelper
  def fixture_command(*command)
    o, e, s = Open3.capture3(*command)
    return o if s.success?

    raise "command failed: #{command.join(" ")}\n#{e}"
  end

  def compile_fixture(output:, input:, options: [])
    fixture_command("gcc", *options, "-S", "-o", output, input)
    output
  end

  def assemble_fixture(output:, input:)
    fixture_command("as", "-o", output, input)
    output
  end

  def build_archive(output:, inputs:)
    fixture_command("ar", "rcsD", output, *inputs)
    output
  end

  def create_archive(output:, inputs:, options: [])
    inputs = inputs.map { |input| create_object(output: File.basename(input, ".c") + ".o", input:, options:) }
    build_archive(output:, inputs:)
  end

  def create_object(output:, input:, options: [])
    compiler_output = compile_fixture(output: File.basename(input, ".c") + ".s", input:, options:)
    @generated << compiler_output
    input = compiler_output
    assembler_output = assemble_fixture(output:, input:)
    @generated << assembler_output
    assembler_output
  end

  def create_objects(output:, inputs:, options: [], execution_options: [])
    inputs = inputs.map { |input| create_object(output:, input:, options:) }
    fixture_command("gcc", *execution_options, "-o", output, *inputs)
  end
end

module TestProcessHelper
  def check_process(status)
    exit_code = status >> 8
    handle_code = status & 0x7f
    [exit_code, handle_code]
  end
end
