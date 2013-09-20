require 'puppet/property'

module Puppet
  class Property
    # This subclass of {Puppet::Property} manages string key value pairs.
    # In order to use this property:
    #
    # * the _should_ value must be an array of key-value pairs separated by the 'separator'
    # * the retrieve method should return a hash with the keys as symbols
    # @note **IMPORTANT**: In order for this property to work there must also be a 'membership' parameter
    #   The class that inherits from property should override that method with the symbol for the membership
    # @todo The node with an important message is not very clear.
    #
    class KeyValue < Property

      def hash_to_key_value_s(hash)
        hash.select { |k,v| true }.map { |pair| pair.join(separator) }.join(delimiter)
      end

      def should_to_s(should_value)
        hash_to_key_value_s(should_value)
      end

      def is_to_s(current_value)
        hash_to_key_value_s(current_value)
      end

      def membership
        :key_value_membership
      end

      def inclusive?
        @resource[membership] == :inclusive
      end

      def hashify(key_value_array)
        #turns string array into a hash
        key_value_array.inject({}) do |hash, key_value|
          tmp = key_value.split(separator)
          hash[tmp[0].intern] = tmp[1]
          hash
        end
      end

      def process_current_hash(current)
        return {} if current == :absent

        #inclusive means we are managing everything so if it isn't in should, its gone
        current.each_key { |key| current[key] = nil } if inclusive?
        current
      end

      def should
        return nil unless @should

        members = hashify(@should)
        current = process_current_hash(retrieve)

        #shared keys will get overwritten by members
        current.merge(members)
      end

      # @return [String] Returns a default separator of "="
      def separator
        "="
      end

      # @return [String] Returns a default delimiter of ";"
      def delimiter
        ";"
      end

      # Retrieves the key-hash from the provider by invoking its method named the same as this property.
      # @return [Hash] the hash from the provider, or `:absent`
      #
      def retrieve
        #ok, some 'convention' if the keyvalue property is named properties, provider should implement a properties method
        if key_hash = provider.send(name) and key_hash != :absent
          return key_hash
        else
          return :absent
        end
      end

      # Returns true if there is no _is_ value, else returns if _is_ is equal to _should_ using == as comparison.
      # @return [Boolean] whether the property is in sync or not.
      #
      def insync?(is)
        return true unless is

        (is == self.should)
      end
    end
  end
end
