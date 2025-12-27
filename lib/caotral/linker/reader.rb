class Caotral::Linker::Reader
  attr_reader :sections
  def self.read!(input:, debug: false, linker_options: [])
    new(input:, debug:, linker_options:).read
  end

  def initialize(input:, debug: false, linker_options: [])
    @input = decision(input)
    @bin = @input.read
    @context = Caotral::Linker::ELF.new
  end

  def read
    @context
  ensure
    @input.close
  end

  private

  def decision(input)
    case input
    when String, Pathname
      File.open(File.expand_path(input.to_s), "rb")
    else
      raise ArgumentError, "wrong input type"
    end
  end
end
