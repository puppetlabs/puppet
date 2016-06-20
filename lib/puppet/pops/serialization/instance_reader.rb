module Puppet::Pops
module Serialization
  module InstanceReader
    def read(impl_class, value_count, deserializer)
      Serialization.not_implemented(self, 'read')
    end
  end
end
end
