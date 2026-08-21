require_relative "../archive"

module Caotral
  module Binary
    class Archive
      class Reader
        attr_reader :archive

        def initialize(path)
          input = decision(path)
          @bin = StringIO.new(input.read)
          @archive = Caotral::Binary::Archive.new
        end

        def read!
          _magic = @bin.read(8)
          nt = nil
          until @bin.eof?
            offset = @bin.pos
            header = Caotral::Binary::Archive::Header.new(@bin.read(60))
            size = header.size
            body = @bin.read(size)
            raw_name = header.name
            case header.name
            when "/"
              archive.symbol_tables << Caotral::Binary::Archive::SymbolTable.new(body:).parse!
            when "//"
              nt = archive.name_table = Caotral::Binary::Archive::NameTable.new(body:).parse!
            else
              name = if /\A\/(?<idx>\d+)\z/ =~ raw_name
                       nt.resolve(Integer(idx, 10))
                     else
                       raw_name.delete_suffix("/")
                     end

              archive.members << Caotral::Binary::Archive::Member.new(name:, body:, offset:).read!
            end
            @bin.read(1) if size.odd?
          end
        end

        private
        def decision(path)
          case path
          when String, Pathname
            File.open(File.expand_path(path.to_s), "rb")
          else
            raise ArgumentError, "wrong input type"
          end
        end
      end
    end
  end
end
