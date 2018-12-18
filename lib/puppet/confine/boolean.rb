require 'puppet/confine'

# Common module for the Boolean confines. It currently
# contains just enough code to implement PUP-9336.
class Puppet::Confine
  module Boolean
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
      if @values.length == 1 && @values.first.respond_to?(:call)
        # We have a lambda, so evaluate it.
        [@values.first.call]
      else
        @values
      end
    end
  end
end
