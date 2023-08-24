class Vaporware::Compiler::Assemble
  class ELF::Section
    def build
      build = @bytes.map { |b| b.pack("C*") }
      build << [0].pack("C*") until build.map(&:bytesize).sum % 8 == 0
      build
    end

    def check(val, bytes: 8) = val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes

    class Symtab
      def initialize = @bytes = nil
    end

    class Strtab
      def initialize(name:)
        @name = name
        @bytes = nil
      end
    end

    class Note
      def initialize(type)
        @type = type
        @bytes = nil
      end
    end
  end
end
