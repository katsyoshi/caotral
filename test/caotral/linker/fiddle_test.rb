require_relative "../../test_suite"

class Caotral::Linker::FiddleMethodTest < Test::Unit::TestCase
  include TestProcessHelper
  def setup
    @generated = []
    omit("Ruby::Box is not supported in this environment") unless supported_ruby_box?
  end

  def teardown
    @generated.each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  def test_sample_call_add_method
    @generated = ["libtmp.so", "libtmp.so.o"]
    @file = "sample/C/add.c"
    IO.popen(["gcc", "-fPIC", "-c", "-o", "libtmp.so.o", "%s" % @file]).close
    linker = Caotral::Linker.link!(inputs: ["libtmp.so.o"], output: "libtmp.so", linker: "self", shared: true, executable: false)
    box = Ruby::Box.new
    box.require("./sample/fiddle_add.rb")
    assert_equal(10, box::X.add(3, 7))
  end

  private def supported_ruby_box? = RUBY_VERSION >= "4.0.0" && ENV["RUBY_BOX"] == "1" && defined?(Ruby::Box)
end
