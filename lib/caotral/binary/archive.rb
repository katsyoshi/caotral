require_relative "archive/error"

require_relative "archive/header"
require_relative "archive/member"
require_relative "archive/name_table"
require_relative "archive/symbol_table"

module Caotral
  module Binary
    class Archive
      attr_accessor :name_table
      attr_reader :members, :symbol_tables

      def initialize
        @members = []
        @symbol_tables = []
        @name_table = nil
      end
    end
  end
end
