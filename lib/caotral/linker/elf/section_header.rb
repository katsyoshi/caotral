module Caotral
  class Linker
    class ELF
      class SectionHeader
        SHT = {
          null: 0,
          progbits: 1,
          symtab: 2,
          strtab: 3,
          rela: 4,
          hash: 5,
          dynamic: 6,
          note: 7,
          nobits: 8,
          rel: 9,
          shlib: 10,
          dynsym: 11,
        }.freeze
        SHT_BY_VALUE = SHT.invert.freeze
        include Caotral::Assembler::ELF::Utils
        def initialize
          @name = nil
          @type = nil
          @flags = nil
          @addr = nil
          @offset = nil
          @size = nil
          @link = nil
          @info = nil
          @addralign = nil
          @entsize = nil
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

        def null! = set!(name: 0, type: 0, flags: 0, addr: 0, offset: 0, size: 0, link: 0, info: 0, addralign: 0, entsize: 0)
        def name = get(:name)
        def offset = get(:offset)
        def entsize = get(:entsize)
        def size = get(:size)
        def type = SHT_BY_VALUE[@type.pack("C*").unpack("L<").first]
        def info = get(:info)
        def addr = get(:addr)
        LONG_TYPES = %w[flags addr offset size addralign entsize].freeze
        INT_TYPES = %w[name type link info].freeze

        private_constant :LONG_TYPES, :INT_TYPES

        private def bytes = [@name, @type, @flags, @addr, @offset, @size, @link, @info, @addralign, @entsize]
        private def get(type)
          val = instance_variable_get("@#{type.to_s}").pack("C*")
          case type.to_s
          when *INT_TYPES; val.unpack("L<")
          when *LONG_TYPES; val.unpack("Q<")
          else
            raise "not specified: #{type}"
          end.first
        end
      end
    end
  end
end
