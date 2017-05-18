require 'puppet/property'

# This subclass of Puppet::Property manages a Hash or a deep Hash
# (hash with inner hashes) by comparing only keys in the current state (_is_)
# that are also present in the desired state (_should_).
#
# It is useful for resources that have a JSON or YAML representation that is
# easily parsed to a Hash.
module Puppet
  class Property
    class DeepHash < Property
      def _deep_intersect(current_state, desired_state)
        diff = {}

        current_state.each do |key, value|
          next unless desired_state.keys.include? key
          if value.is_a? Hash
            diff[key] = _deep_intersect(value, desired_state[key])
          else
            diff[key] = value
          end
        end

        diff
      end

      def _deep_transform_values_in_object(object, &block)
        case object
        when Hash
          object.each_with_object({}) do |(key, value), result|
            result[key] = _deep_transform_values_in_object(value, &block)
          end
        when Array
          object.map { |e| _deep_transform_values_in_object(e, &block) }
        else
          yield(object)
        end
      end

      def should
        _deep_transform_values_in_object(super) { |value| value == :undef ? nil : value }
      end

      def insync?(is)
        desired_state = should
        _deep_intersect(is, desired_state) == desired_state
      end

      def change_to_s(current_value, new_value)
        changed_keys = (new_value.to_a - current_value.to_a).collect { |key, _| key }

        current_value = current_value.delete_if { |key, _| !changed_keys.include? key }.inspect
        new_value = new_value.delete_if { |key, _| !changed_keys.include? key }.inspect

        super(current_value, new_value)
      end
    end
  end
end
