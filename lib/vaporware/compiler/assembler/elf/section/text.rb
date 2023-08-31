class Vaporware::Compiler::Assembler::ELF::Section::Text
  PREFIX = {
    REX_W: 0x48,
  }.freeze

  REGISTER_CODE = {
    RAX: 0,
    RDI: 7,
  }.freeze

  OPECODE = {
    ADD: 0x01,
    CQO: 0x99,
    IDIV: 0xf7,
    IMUL: 0x0f,
    MOV: 0x89,
    SUB: 0x83,
  }.freeze

  attr_reader :bytes, :size, :offset

  def initialize
    @bytes = []
    @size = 0
    @offset = 0
  end

  def assemble!(line)
    op, *operands = line.split(/\s+/).reject { |o| o.empty? }.map { |op| op.gsub(/,/, "") }
    @bytes << opecode(op, *operands)
    @size += @bytes.last.bytesize
  end

  def align!(bytes)
    @bytes << [0x00] until @bytes.map(:bytesize).sum % bytes == 0
  end

  private

  def opecode(op, *operands)
    case op
    when "push"
      push(operands)
    when "mov"
      [PREFIX[:REX_W], *mov(op, operands)]
    when "sub", "add", "imul", "cqo", "idiv"
      [PREFIX[:REX_W], *calc(op, operands)]
    when "pop"
      pop(operands)
    when "ret"
      [0xc3]
    end
  end

  def mov(op, operands)
    reg = case operands
          in ["rbp", "rsp"]
            [0xe5]
          in ["rsp", "rbp"]
            [0xec]
          else
            operands&.map { reg(_1) }
          end
    [OPECODE[op.upcase.to_sym], *reg]
  end

  def calc(op, operands)
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
    in ["cqo"]
      [0x99]
    end
  end

  def push(operands)
    case operands
    in ["rbp"] | ["rdi"]
      [0x55]
    in ["rax"]
      [0x50]
    else
      [0x6a, *operands.map { reg(_1) }]
    end
  end

  def pop(operands)
    case operands
    in ["rax"] | ["rdi"]
      [0x58 + REGISTER_CODE[operands.first.upcase.to_sym]]
    in ["rbp"]
      [0x5d]
    end
  end

  def reg(r)
    case r
    in "rsp"
      0xec
    in "rbp"
      0x5e
    in "rax"
      0x29
    in "rdi"
      0xf8
    in /\d+/
      ("%02x" % r).to_i(16)
    end
  end
end
