class Caotral::Linker::ELF::Section::Text
  def initialize = @bytes = []
  def build = @bytes.flatten.pack("C*")
end
