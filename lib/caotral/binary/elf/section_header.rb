require_relative "utils"

module Caotral
  module Binary
    class ELF
      class SectionHeader
        include Caotral::Binary::ELF::Utils
        SHT = { null: 0, progbits: 1, symtab: 2, strtab: 3, rela: 4, hash: 5, dynamic: 6, note: 7, nobits: 8, rel: 9, shlib: 10, dynsym: 11, }.freeze
        SHT_BY_VALUE = SHT.invert.freeze

        def initialize
          @name = num2bytes(0, 4)
          @type = num2bytes(0, 4)
          @flags = num2bytes(0, 8)
          @addr = num2bytes(0, 8)
          @offset = num2bytes(0, 8)
          @size = num2bytes(0, 8)
          @link = num2bytes(0, 4)
          @info = num2bytes(0, 4)
          @addralign = num2bytes(0, 8)
          @entsize = num2bytes(0, 8)
        end

        def build = bytes.flatten.pack("C*")

        def set!(name: nil, type: nil, flags: nil, addr: nil,
                 offset: nil, size: nil, link: nil, info: nil,
                 addralign: nil, entsize: nil)
          @name = num2bytes(name, 4) if check(name, 4)
          @type = num2bytes(type, 4) if check(type, 4)
          @flags = num2bytes(flags, 8)  if check(flags, 8)
          @addr = num2bytes(addr, 8) if check(addr, 8)
          @offset = num2bytes(offset, 8) if check(offset, 8)
          @size = num2bytes(size, 8) if check(size, 8)
          @link = num2bytes(link, 4) if check(link, 4)
          @info = num2bytes(info, 4) if check(info, 4)
          @addralign = num2bytes(addralign, 8) if check(addralign, 8)
          @entsize = num2bytes(entsize, 8) if check(entsize, 8)
          self
        end

        def name = @name.pack("C*").unpack1("L<")
        def offset = @offset.pack("C*").unpack1("Q<")
        def entsize = @entsize.pack("C*").unpack1("Q<")
        def size = @size.pack("C*").unpack1("Q<")
        def type = SHT_BY_VALUE[@type.pack("C*").unpack1("L<")]
        def info = @info.pack("C*").unpack1("L<")
        def addr = @addr.pack("C*").unpack1("Q<")

        private def bytes = [@name, @type, @flags, @addr, @offset, @size, @link, @info, @addralign, @entsize]
      end
    end
  end
end
