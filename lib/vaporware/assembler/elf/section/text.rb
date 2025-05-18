class Vaporware::Assembler::ELF::Section::Text
  PREFIX = {
    REX_W: 0x48,
  }.freeze

  REGISTER_CODE = {
    RAX: 0,
    RDI: 7,
  }.freeze

  OPECODE = {
    ADD:  [0x01],
    CMP:  [0x39],
    CQO:  [0x99],
    IDIV: [0xf7],
    IMUL: [0x0f],
    MOV:  [0x89],
    MOVR: [0x8B],
    MOVXZ: [0x0f, 0xb7],
    SUB: [0x83],
  }.freeze
  HEX_PATTERN = /\A0x[0-9a-fA-F]+\z/.freeze

  def initialize(**opts) = @bytes = []

  def assemble!(line)
    op, *operands = line.split(/\s+/).reject { |o| o.empty? }.map { |op| op.gsub(/,/, "") }
    @bytes << opecode(op, *operands)
  end

  def build = @bytes.flatten.pack("C*")
  def size = build.bytesize
  def align(val, bytes) = (val << [0] until build.bytesize % bytes == 0)

  private

  def opecode(op, *operands)
    case op
    when "push"
      push(*operands)
    when "mov", "movzb"
      [PREFIX[:REX_W], *mov(op, *operands)]
    when "sub", "add", "imul", "cqo", "idiv"
      [PREFIX[:REX_W], *calc(op, *operands)]
    when "pop"
      pop(*operands)
    when "cmp"
      [PREFIX[:REX_W], *cmp(op, *operands)]
    when "sete", "setl"
      sete(op, *operands)
    when "je", "jmp"
      jump(op, *operands)
    when "syscall"
      [0x0f, 0x05]
    when "ret"
      [0xc3]
    else
      raise Vaporware::Assembler::ELF::Error, "yet implemented operations: #{op}"
    end
  end

  def jump(op, *operands)
    opecode = case op
              when "je"
                [0x74]
              when "jmp"
                [0xeb]
              end
    addr = case operands
           in [".Lend0"]
             [0x08]
           in [".Lelse0"]
             [0x0a]
           in [".Lbegin0"]
             opecode = [0xe9]
             [0x48, 0xff, 0xff, 0xff]
           end # steep:ignore
    [opecode, addr].flatten
  end

  def mov(op, *operands)
    reg = case operands
          in ["rax", "rbp"]
            [0xe8]
          in ["rbp", "rsp"]
            [0xe5]
          in ["rsp", "rbp"]
            [0xec]
          in ["[rax]", "rdi"]
            [0x38]
          in ["rax", "al"]
            op = "MOVXZ"
            [0xc0]
          in ["rax", "[rax]"]
            op = "MOVR"
            [0x00]
          in ["rdi", "rax"]
            [0xC7]
          in ["rax", HEX_PATTERN]
            return [0xC7, 0xC0, *immediate(operands[1])]
          else
            operands&.map { reg(_1) }
          end # steep:ignore
    [OPECODE[op.upcase.to_sym], reg].flatten
  end

  def calc(op, *operands)
    ope_code = OPECODE[op.upcase.to_sym]
    case [op, *operands]
    in ["sub", "rax", "rdi"]
      [0x29, 0xf8]
    in ["add", "rax", "rdi"]
      [ope_code, 0xf8]
    in ["imul", "rax", "rdi"]
      [ope_code, 0xaf, 0xc7]
    in ["idiv", "rdi"]
      [ope_code, 0xff]
    in ["sub", "rsp", *num]
      [ope_code, 0xec, *num.map { |n| n.to_i(16) }]
    in ["sub", "rax", *num]
      [ope_code, 0xe8, *num.map { |n| n.to_i(16) }]
    in ["cqo"]
      [0x99]
    end # steep:ignore
  end

  def cmp(op, *operands)
    case operands
    in ["rax", "rdi"]
      [0x39, 0xf8]
    in ["rax", "0"]
      [0x83, 0xf8, 0x00]
    end # steep:ignore
  end

  def sete(op, *operands)
    case [op, operands]
    in ["sete", ["al"]]
      [0x0f, 0x94, 0xc0]
    in ["setl", ["al"]]
      [0x0f, 0x9c, 0xc0]
    end # steep:ignore
  end

  def push(*operands)
    case operands
    in ["rbp"] | ["rdi"]
      [0x55]
    in ["rax"]
      [0x50]
    in [HEX_PATTERN]
       [0x68, *immediate(operands.first)]
    else
      [0x6a, *operands.map { |o| reg(o) }]
    end # steep:ignore
  end

  def pop(*operands)
    case operands
    in ["rax"] | ["rdi"]
      [0x58 + REGISTER_CODE[operands.first.upcase.to_sym]]
    in ["rbp"]
      [0x5d]
    end # steep:ignore
  end

  def reg(r)
    case r
    when "rsp"
      0xec
    when "rbp"
      0x5e
    when "rax"
      0x29
    when "rdi"
      0xf8
    when /\d+/
      r.to_i(16)
    else
      raise Vaporware::Assembler::ELF::Error, "yet implemented operand address: #{r}"
    end
  end
  def immediate(operand) = [operand.to_i(16)].pack("L").unpack("C*")
end
