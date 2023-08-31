class Vaporware::Compiler::Assembler::ELF::Section
  def build!
    build = @bytes.map { |b| b.pack("C*") }
    build << [0].pack("C*") until build.map(&:bytesize).sum % 8 == 0
    build
  end

  def check(val, bytes: 8) = val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes
end
