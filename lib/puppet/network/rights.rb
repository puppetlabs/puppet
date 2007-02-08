require 'ipaddr'
require 'puppet/network/authstore'

# Define a set of rights and who has access to them.
class Puppet::Network::Rights < Hash
    # We basically just proxy directly to our rights.  Each Right stores
    # its own auth abilities.
    [:allow, :allowed?, :deny].each do |method|
        define_method(method) do |name, *args|
            name = name.intern if name.is_a? String

            if obj = right(name)
                obj.send(method, *args)
            else
                raise ArgumentError, "Unknown right '%s'" % name
            end
        end
    end

    def [](name)
        name = name.intern if name.is_a? String
        super(name)
    end

    # Define a new right to which access can be provided.
    def newright(name)
        name = name.intern if name.is_a? String
        shortname = Right.shortname(name)
        if self.include? name
            raise ArgumentError, "Right '%s' is already defined" % name
        else
            self[name] = Right.new(name, shortname)
        end
    end

    private

    # Retrieve a right by name.
    def right(name)
        name = name.intern if name.is_a? String
        self[name]
    end

    # A right.
    class Right < Puppet::Network::AuthStore
        attr_accessor :name, :shortname

        Puppet::Util.logmethods(self, true)

        def self.shortname(name)
            name.to_s[0..0]
        end

        def initialize(name, shortname = nil)
            @name = name
            @shortname = shortname
            unless @shortname
                @shortname = Right.shortname(name)
            end
            super()
        end

        def to_s
            "access[%s]" % @name
        end

        # There's no real check to do at this point
        def valid?
            true
        end
    end
end

# $Id$
