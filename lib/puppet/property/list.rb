require 'puppet/property'

module Puppet
  class Property
    # This subclass of {Puppet::Property} manages an unordered list of values.
    # For an ordered list see {Puppet::Property::OrderedList}.
    #
    class List < Property

      def is_to_s(currentvalue)
        currentvalue == :absent ? super(currentvalue) : currentvalue.join(delimiter)
      end

      def membership
        :membership
      end

      def add_should_with_current(should, current)
        should += current if current.is_a?(Array)
        should.uniq
      end

      def inclusive?
        @resource[membership] == :inclusive
      end

      #dearrayify was motivated because to simplify the implementation of the OrderedList property
      def dearrayify(array)
        array.sort.join(delimiter)
      end

      def should
        return nil unless @should

        members = @should
        #inclusive means we are managing everything so if it isn't in should, its gone
        members = add_should_with_current(members, retrieve) if ! inclusive?

        dearrayify(members)
      end

      def delimiter
        ","
      end

      def retrieve
        #ok, some 'convention' if the list property is named groups, provider should implement a groups method
        if provider and tmp = provider.send(name) and tmp != :absent
          return tmp.split(delimiter)
        else
          return :absent
        end
      end

      def prepare_is_for_comparison(is)
        if is == :absent
          is = []
        end
        dearrayify(is)
      end

      def insync?(is)
        return true unless is

        (prepare_is_for_comparison(is) == self.should)
      end
    end
  end
end
