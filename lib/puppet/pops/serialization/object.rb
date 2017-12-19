require_relative 'instance_reader'
require_relative 'instance_writer'

module Puppet::Pops
module Serialization

# Instance reader for objects that implement {Types::PuppetObject}
# @api private
class ObjectReader
  include InstanceReader

  def read(type, impl_class, value_count, deserializer)
    (names, types, required_count) = type.parameter_info(impl_class)
    max = names.size
    unless value_count >= required_count && value_count <= max
      raise Serialization::SerializationError, _("Feature count mismatch for %{value0}. Expected %{required_count} - %{max}, actual %{value_count}") % { value0: impl_class.name, required_count: required_count, max: max, value_count: value_count }
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
        raise Serialization::SerializationError, _("Missing default value for %{type_name}[%{name}]") % { type_name: type.name, name: names[index] } unless attr && attr.value?
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
    (names, _, required_count) = type.parameter_info(impl_class)
    args = names.map { |name| value.send(name) }

    # Pop optional arguments that are default
    while args.size > required_count
      break unless type[names[args.size-1]].default_value?(args.last)
      args.pop
    end

    if type.name.start_with?('Pcore::') || serializer.type_by_reference?
      serializer.push_written(value)
      serializer.start_pcore_object(type.name, args.size)
    else
      serializer.start_object(args.size + 1)
      serializer.write(type)
      serializer.push_written(value)
    end

    args.each { |arg| serializer.write(arg) }
  end

  INSTANCE = ObjectWriter.new
end
end
end

