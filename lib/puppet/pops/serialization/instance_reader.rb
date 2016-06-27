module Puppet::Pops
module Serialization
  # An InstanceReader is responsible for reading an instance of a complex object using a deserializer. The read involves creating the
  # instance, register it with the deserializer (so that self references can be resolved) and then read the instance data (which normally
  # amounts to all attribute values).
  # Instance readers are registered with of {Types::PObjectType}s to aid the type when reading instances.
  #
  # @api private
  module InstanceReader
    # @param [Class] impl_class the class of the instance to be created and initialized
    # @param [Integer] value_count the expected number of objects that forms the initialization data
    # @param [Deserializer] deserializer the deserializer to read from, and to register the instance with
    # @return [Object] the instance that has been read
    def read(impl_class, value_count, deserializer)
      Serialization.not_implemented(self, 'read')
    end
  end
end
end
