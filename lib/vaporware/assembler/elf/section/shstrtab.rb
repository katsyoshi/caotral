class Vaporware::Assembler::ELF::Section::Shstrtab
  include Vaporware::Assembler::ELF::Utils
  def initialize(**opts) = @name = []
  def build = bytes.flatten.pack("C*")
  def set!(name:) = (@name << name!(name); self)

  private
  def bytes = [@name, [0]]
  def name!(name)
    case name
    when String
      (name.match(/\A\0\..+\z/) ? name : "\0.#{name}").bytes
    when Array
      raise Vaporware::Assembler::ELF::Error, "unaccepted type in Array" unless name.all? { |elem| elem.is_a?(Integer) }
      n = name
      n.unshift(0) && n.push(0) unless n.first == 0 && n.last == 0
      n
    else
      raise Vaporware::Assembler::ELF::Error, "unsupported type"
    end
  end
end
