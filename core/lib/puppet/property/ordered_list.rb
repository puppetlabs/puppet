require 'puppet/property/list'

module Puppet
  class Property
    # This subclass of {Puppet::Property} manages an ordered list of values.
    # The maintained order is the order defined by the 'current' set of values (i.e. the
    # original order is not disrupted). Any additions are added after the current values
    # in their given order).
    #
    # For an unordered list see {Puppet::Property::List}.
    #
    class OrderedList < List

      def add_should_with_current(should, current)
        if current.is_a?(Array)
          #tricky trick
          #Preserve all the current items in the list
          #but move them to the back of the line
          should = should + (current - should)
        end
        should
      end

      def dearrayify(array)
        array.join(delimiter)
      end
    end
  end
end
