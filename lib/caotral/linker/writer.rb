class Caotral::Linker::Writer
  attr_reader :elf_obj, :output, :debug
  def self.write!(elf_obj:, output:, debug: false)
    new(elf_obj:, output:, debug:).write
  end
  def initialize(elf_obj:, output:, debug: false) = @elf_obj, @output, @debug = elf_obj, output, debug
  def write = output
end
