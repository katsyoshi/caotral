class Vaporware::Compiler::Assembler::ELF
  class SectionHeader
    def initialize(endian: :littel, addr: [0]*8)
      @name = nil
      @type = nil
      @flags = nil
      @addr = addr
      @offset = nil
      @size = nil
      @link = nil
      @info = nil
      @addralign = nil
      @entsize = nil
    end

    def build!
      [
        @name,
        @type,
        @flags,
        @addr,
        @offset,
        @size,
        @link,
        @info,
        @addralign,
        @entsize,
      ].flatten.pack("C*")
    end

    def set!(name: nil, type: nil, flags: nil, addr: nil,
      offset: nil, size: nil, link: nil, info: nil,
      addralign: nil, entsize: nil
    )
      @name = name if check(name, 4)
      @type = type if check(type, 4)
      @flags = flags if check(flags, 8)
      @addr = addr if check(addr, 8)
      @offset = offset if check(offset, 8)
      @size = size if check(size, 8)
      @link = link if check(link, 4)
      @info = info if check(info, 4)
      @addralign = addralign if check(addralign, 8)
      @entsize = entsize if check(entsize, 8)
    end

    def set_null!
      @name = num2bytes(@name, bytes: 4)
      @type = num2bytes(@type, bytes: 4)
      @flags = num2bytes(@flags)
      @addr = num2bytes(@addr)
      @offset = num2bytes(@offset)
      @size = num2bytes(@size)
      @link = num2bytes(@link, bytes: 4)
      @info = num2bytes(@info, bytes: 4)
      @addralign = num2bytes(@addralign)
      @entsize = num2bytes(@entsie)
   end

    private

    def check(val, bytes) = val.is_a?(Array) && val.all? { |v| v.is_a?(Integer) } && val.size == bytes

    def num2bytes(val, bytes: 8, endian: :littel) = ("%0#{byte}x" % val).scan(/.{1,2}/).map { |x| x.to_i(16) }.then { |a| endian == :littel ? a.reverse : a }
  end
end
