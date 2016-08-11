module Puppet::Pops
module Serialization
  # An instance writer is responsible for writing complex objects using a {Serializer}
  # @api private
  module InstanceWriter
    # @param [Types::PObjectType] type the type of instance to write
    # @param [Object] value the instance
    # @param [Serializer] serializer the serializer that will receive the written instance
    def write(type, value, serializer)
      Serialization.not_implemented(self, 'write')
    end
  end
end
end
