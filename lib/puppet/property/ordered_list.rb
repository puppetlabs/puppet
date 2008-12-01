require 'puppet/property/list'

module Puppet
    class Property
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
