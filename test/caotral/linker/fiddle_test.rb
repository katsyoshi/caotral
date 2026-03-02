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
    Caotral::Linker.link!(inputs: ["libtmp.so.o"], output: "libtmp.so", linker: "self", shared: true, executable: false)
    elf = Caotral::Binary::ELF::Reader.read!(input: "./libtmp.so")
    box = Ruby::Box.new
    box.require("./sample/fiddle_add.rb")
    assert_equal(10, box::X.add(3, 7))
    dynsym = elf.find_by_name(".dynsym")
    rela_plt = elf.find_by_name(".rela.plt")
    dynamic = elf.find_by_name(".dynamic")
    dynstr = elf.find_by_name(".dynstr")
    dynstrs = dynstr.body.names.split("\x00")
    assert(dynstrs.include?("add"))
    assert_equal(2, dynsym.body.size)
    assert_equal("add", dynstr.body.lookup(dynsym.body[1].name_offset))
    assert_equal(0, rela_plt.body.size)
    assert_equal(nil, dynamic.body.find { |dt| dt.plt_rel? })
    assert_equal(nil, dynamic.body.find { |dt| dt.plt_rel_size? })
    assert_equal(nil, dynamic.body.find { |dt| dt.jmp_rel? })
  end

  private def supported_ruby_box? = RUBY_VERSION >= "4.0.0" && ENV["RUBY_BOX"] == "1" && defined?(Ruby::Box)
end
