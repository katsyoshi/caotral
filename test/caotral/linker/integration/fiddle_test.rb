require_relative "../../../test_suite"

class Caotral::Linker::FiddleMethodTest < Test::Unit::TestCase
  include TestProcessHelper
  def setup = setup_ruby_box
  def teardown = teardown_native_binary

  def test_sample_call_add_method
    library = "libtmp.so"
    object = "libtmp.so.o"
    @generated = [library, object]
    @file = "sample/C/add.c"
    IO.popen(["gcc", "-fPIC", "-c", "-o", object, @file]).close
    Caotral::Linker.link!(inputs: [object], output: library, linker: "self", shared: true, executable: false)
    elf = Caotral::Binary::ELF::Reader.read!(input: library)
    box = Ruby::Box.new
    box.require("./sample/fiddle_add.rb")
    handles = box::X.handler.handlers
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
  ensure
    handles&.each(&:close)
  end
end
