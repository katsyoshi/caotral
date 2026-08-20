require_relative "archive/header"
require_relative "archive/member"

module Caotral
  module Binary
    class Archive
      attr_reader :members

      def initialize
        @members = []
      end
    end
  end
end
