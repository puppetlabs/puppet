module Puppet::Pops
module Serialization
  def self.not_implemented(impl, method_name)
    raise NotImplementedError, "The class #{impl.class.name} should have implemented the method #{method_name}()"
  end

  class SerializationError < Puppet::Error
  end

  PCORE_TYPE_KEY = '__pcore_type__'.freeze

  # Key used when the value can be represented as, and recreated from, a single string that can
  # be passed to a `from_string` method or an array of values that can be passed to the default
  # initializer method.
  PCORE_VALUE_KEY = '__pcore_value__'.freeze

  # Type key used for hashes that contain keys that are not of type String
  PCORE_TYPE_HASH = 'Hash'.freeze

  # Type key used for symbols
  PCORE_TYPE_SENSITIVE = 'Sensitive'.freeze

  # Type key used for symbols
  PCORE_TYPE_SYMBOL = 'Symbol'.freeze

  # Type key used for Default
  PCORE_TYPE_DEFAULT = 'Default'.freeze

  # Type key used for document local references
  PCORE_LOCAL_REF_SYMBOL = 'LocalRef'.freeze
end
end

require_relative 'serialization/json_path'
require_relative 'serialization/from_data_converter'
require_relative 'serialization/to_data_converter'
require_relative 'serialization/serializer'
require_relative 'serialization/deserializer'
require_relative 'serialization/json'
require_relative 'serialization/time_factory'
require_relative 'serialization/object'
