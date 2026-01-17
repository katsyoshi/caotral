require "caotral"
require "test/unit"
require "pathname"

module TestProcessHelper
  private
  def check_process(status)
    exit_code = status >> 8
    handle_code = status & 0x7f
    [exit_code, handle_code]
  end
end
