require_relative "../../test_suite"

class Caotral::Linker::SymbolRemapTest < Test::Unit::TestCase
  include TestProcessHelper
  def teardown
    @generated.each do |file|
      File.delete(file) if File.exist?(file)
    end
  end
  def test_remap_external_symbols
    base_name = "symbol_remap_external"
    inputs = ["_a", "_b"].map { base_name + it + ".o" }
    files = inputs.map { "sample/C/#{it.sub(/\.o$/, ".c")}" }
    execute = "combined"
    @generated = [execute] + inputs
    inputs.zip(files).each { |o, i| IO.popen(["gcc", "-fPIC", "-c", "-o", o, "%s" % i]).close }
    Caotral::Linker.link!(inputs:, output: execute, linker: "self", pie: true)
    elf = Caotral::Binary::ELF::Reader.read!(input: execute)
    dynsym = elf.find_by_name(".dynsym")
    dynsym_names = dynsym.body.map(&:name_string)
    assert_equal(3, dynsym.body.size)
    assert_include(dynsym_names, "main")
    assert_include(dynsym_names, "value_from_b")
    assert_not_include(dynsym_names, "hidden_value")
    assert_not_include(dynsym_names, "symbol_remap_external_b.c")
    assert_empty(elf.find_by_name(".rela.plt").body)
    _o, _e, status = Open3.capture3("./#{execute}")
    ec, hc = check_process(status.to_i)
    assert_equal(ec, 42)
  end
end
