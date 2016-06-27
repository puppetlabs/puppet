require_relative 'instance_reader'
require_relative 'instance_writer'

module Puppet::Pops
module Serialization

# Instance reader for objects that implement {Types::PuppetObject}
# @api private
class ObjectReader
  include InstanceReader

  def read(impl_class, value_count, deserializer)
    type = impl_class._ptype
    (names, types, required_count) = type.parameter_info
    max = names.size
    unless value_count >= required_count && value_count <= max
      raise Serialization::SerializationError, "Feature count mismatch for #{impl_class.name}. Expected #{min} - #{max}, actual #{value_count}"
    end
    # Deserializer must know about this instance before we read its attributes
    val = deserializer.remember(impl_class.allocate)
    args = Array.new(value_count) { deserializer.read }
    types.each_with_index do |ptype, index|
      if index < args.size
        arg = args[index]
        Types::TypeAsserter.assert_instance_of(nil, ptype, arg) { "#{type.name}[#{names[index]}]" } unless arg == :default
      else
        attr = type[names[index]]
        raise Serialization::SerializationError, "Missing default value for #{type.name}[#{names[index]}]" unless attr.value?
        args << attr.value
      end
    end
    val.send(:initialize, *args)
    val
  end

  INSTANCE = ObjectReader.new
end

# Instance writer for objects that implement {Types::PuppetObject}
# @api private
class ObjectWriter
  include InstanceWriter

  def write(type, value, serializer)
    impl_class = value.class
    (names, types, required_count) = type.parameter_info(true)
    args = names.map { |name| value.send(name) }

    # Pop optional arguments that are nil
    while args.size > required_count
      break unless args.last.nil?
      args.pop
    end

    serializer.start_object(type.name, args.size)
    args.each { |arg| serializer.write(arg) }
  end

  INSTANCE = ObjectWriter.new
end
end
end

