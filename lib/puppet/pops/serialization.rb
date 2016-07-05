module Puppet::Pops
module Serialization
  def self.not_implemented(impl, method_name)
    raise NotImplementedError, "The class #{impl.class.name} should have implemented the method #{method_name}()"
  end

  class SerializationError < Puppet::Error
  end
end
end

require_relative 'serialization/serializer'
require_relative 'serialization/deserializer'
require_relative 'serialization/json'
require_relative 'serialization/time_factory'
require_relative 'serialization/rgen'
require_relative 'serialization/object'
