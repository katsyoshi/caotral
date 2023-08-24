class Vaporware::Compiler::Assemble
  class ELF::Section::Strtab
    attr_reader :bytes
    def initialize(name: "main") = @bytes = "\0main\0"

    def build! = @bytes.bytes.pack("C*")
  end
end
