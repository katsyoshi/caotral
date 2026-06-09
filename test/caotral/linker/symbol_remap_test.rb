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
    @generated = ["libtmp.so"] + inputs
    inputs.zip(files).each { |o, i| IO.popen(["gcc", "-fPIC", "-c", "-o", o, "%s" % i]).close }
    Caotral::Linker.link!(inputs:, output: "libtmp.so", linker: "self", pie: true)
    elf = Caotral::Binary::ELF::Reader.read!(input: "./libtmp.so")
    assert_equal(2, elf.find_by_name(".dynsym").body.size)
  end
end
