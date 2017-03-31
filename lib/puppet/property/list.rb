require 'puppet/property'

module Puppet
  class Property
    # This subclass of {Puppet::Property} manages an unordered list of values.
    # For an ordered list see {Puppet::Property::OrderedList}.
    #
    class List < Property

      def should_to_s(should_value)
        #just return the should value
        should_value
      end

      def is_to_s(currentvalue)
        if currentvalue == :absent
          return "absent"
        else
          return currentvalue.join(delimiter)
        end
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

      def members
        return nil unless @should

        #inclusive means we are managing everything so if it isn't in should, its gone
        if inclusive?
          @should
        else
          add_should_with_current(@should, retrieve)
        end
      end

      def should
        tmp = members
        dearrayify(tmp) if ! tmp.nil?
      end

      # Returns any values from the list that were returned by
      # retrieve but are not set as being managed.
      def is_but_shouldnt
        # We know that if inclusive is not set, we won't have to
        # remove any values from the system.
        inclusive? ? Set.new(retrieve) - Set.new(@should) : Set.new()
      end

      # Returns any values from the list that we are managing but that
      # were not returned by retrieve
      def should_but_isnt
        Set.new(@should) - Set.new(retrieve)
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
