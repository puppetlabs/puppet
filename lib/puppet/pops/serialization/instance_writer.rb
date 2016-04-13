module Puppet::Pops
module Serialization
  module InstanceWriter
    def write(type, value, serializer)
      Serialization.not_implemented(self, 'write')
    end
  end
end
end
