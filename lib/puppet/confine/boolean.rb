require 'puppet/confine'

# Common module for the Boolean confines. It currently
# contains just enough code to implement PUP-9336.
class Puppet::Confine
  module Boolean
    # Returns the passing value for the Boolean confine.
    def passing_value
      raise NotImplementedError, "The Boolean confine %{confine} must provide the passing value." % { confine: self.class.name }
    end

    # The Boolean confines 'true' and 'false' let the user specify
    # two types of values:
    #     * A lambda for lazy evaluation. This would be something like
    #         confine :true => lambda { true }
    #
    #     * A single Boolean value, or an array of Boolean values. This would
    #     be something like
    #         confine :true => true OR confine :true => [true, false, false, true]
    #
    # This override distinguishes between the two cases.
    def values
      # Note that Puppet::Confine's constructor ensures that @values
      # will always be an array, even if a lambda's passed in. This is
      # why we have the length == 1 check.
      unless @values.length == 1 && @values.first.respond_to?(:call)
        return @values
      end

      # We have a lambda. Here, we want to enforce "cache positive"
      # behavior, which is to cache the result _if_ it evaluates to
      # the passing value (i.e. the class name).

      return @cached_value unless @cached_value.nil?

      # Double negate to coerce the value into a Boolean
      calculated_value = !! @values.first.call
      if calculated_value == passing_value
        @cached_value = [calculated_value]
      end

      [calculated_value]
    end
  end
end
