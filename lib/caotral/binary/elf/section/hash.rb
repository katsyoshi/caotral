require "caotral/binary/elf/utils"
module Caotral
  module Binary
    class ELF
      class Section
        class Hash
          include Caotral::Binary::ELF::Utils
          attr_reader :bucket, :chain
          def initialize(nchain:, nbucket: 1)
            @nbucket = num2bytes(nbucket, 4)
            @nchain = num2bytes(nchain, 4)
            @bucket = Array.new(nbucket, num2bytes(0, 4))
            @chain = Array.new(nchain, num2bytes(0, 4))
          end

          private def bytes = [@nbucket, @nchain, *@bucket, *@chain]
        end
      end
    end
  end
end
