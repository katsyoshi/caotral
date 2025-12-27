class Caotral::Linker::ELF
  def self.link!(input:, output:, debug: false)
    elf = new
    elf_obj = Caotral::Linker::ELF::Reader.read!(input:, debug:)
    Caotral::Linker::ELF::Writer.write!(elf_obj:, output:, debug:)
    output
  end
end
