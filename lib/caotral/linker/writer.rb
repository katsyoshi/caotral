class Caotral::Linker::Writer
  attr_reader :elf_obj, :output, :entry, :debug
  def self.write!(elf_obj:, output:, entry: nil, debug: false)
    new(elf_obj:, output:, entry:, debug:).write
  end
  def initialize(elf_obj:, output:, entry: nil, debug: false) = @elf_obj, @output, @entry, @debug = elf_obj, output, entry, debug
  def write = output
end
