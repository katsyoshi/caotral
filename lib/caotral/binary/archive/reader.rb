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
          archive.members << Caotral::Binary::Archive::Member.new(@bin) until @bin.eof?
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
