require "fiddle/import"

module X
  extend Fiddle::Importer
  dlload "./libtmp.so"
  extern "int aibo()"
end
