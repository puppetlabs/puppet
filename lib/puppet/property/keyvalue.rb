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
      class << self
        # This is a class-level variable that child properties can override
        # if they wish.
        attr_accessor :log_only_changed_or_new_keys
      end

      self.log_only_changed_or_new_keys = false

      def hash_to_key_value_s(hash)
        if self.class.log_only_changed_or_new_keys
          hash = hash.select { |k, _| @changed_or_new_keys.include?(k) }
        end

        hash.map { |*pair| pair.join(separator) }.join(delimiter)
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

      def hashify_should
        # Puppet casts all should values to arrays. Thus, if the user
        # passed in a hash for our property's should value, the should_value
        # parameter will be a single element array so we just extract our value
        # directly.
        if ! @should.empty? && @should.first.is_a?(Hash)
          return @should.first
        end

        # Here, should is an array of key/value pairs.
        @should.inject({}) do |hash, key_value|
          tmp = key_value.split(separator)
          hash[tmp[0].strip.intern] = tmp[1]
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

        members = hashify_should
        current = process_current_hash(retrieve)

        #shared keys will get overwritten by members
        should_value = current.merge(members)

        # Figure out the keys that will actually change in our Puppet run.
        # This lets us reduce the verbosity of Puppet's logging for instances
        # of this class when we want to.
        #
        # NOTE: We use ||= here because we only need to compute the
        # changed_or_new_keys once (since this property will only be synced once).
        #
        @changed_or_new_keys ||= should_value.keys.select do |key|
          ! current.key?(key) || current[key] != should_value[key]
        end

        should_value
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
      def insync?(is)
        return true unless is

        (is == self.should)
      end

      # We only accept an array of key/value pairs (strings), a single
      # key/value pair (string) or a Hash as valid values for our property.
      # Note that for an array property value, the 'value' passed into the
      # block corresponds to the array element.
      validate do |value|
        unless value.is_a?(String) || value.is_a?(Hash)
          raise ArgumentError, _("The %{name} property must be specified as a hash or an array of key/value pairs (strings)!") % { name: name }
        end

        next if value.is_a?(Hash)

        unless value.include?("#{separator}")
          raise ArgumentError, _("Key/value pairs must be separated by '%{separator}'") % {separator: separator}
        end
      end

      # The validate step ensures that our passed-in value is
      # either a String or a Hash. If our value's a string,
      # then nothing else needs to be done. Otherwise, we need
      # to stringify the hash's keys and values to match our
      # internal representation of the property's value.
      munge do |value|
        next value if value.is_a?(String)

        munged_value = value.to_a.map! do |hash_key, hash_value|
          [hash_key.to_s.strip.to_sym, hash_value.to_s]
        end

        Hash[munged_value]
      end
    end
  end
end
