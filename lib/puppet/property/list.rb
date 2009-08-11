require 'puppet/property'

module Puppet
    class Property
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
                if current.is_a?(Array)
                    should += current
                end
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
                unless defined? @should and @should
                    return nil
                end

                members = @should
                #inclusive means we are managing everything so if it isn't in should, its gone
                if ! inclusive?
                    members = add_should_with_current(members, retrieve)
                end

                dearrayify(members)
            end

            def delimiter
                ","
            end

            def retrieve
                #ok, some 'convention' if the list property is named groups, provider should implement a groups method
                if tmp = provider.send(name) and tmp != :absent
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
                unless defined? @should and @should
                    return true
                end

                unless is
                    return true
                end

                return (prepare_is_for_comparison(is) == self.should)
            end
        end
    end
end
