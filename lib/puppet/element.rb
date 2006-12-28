# included so we can test object types
require 'puppet'

# the base class for both types and states
# very little functionality; basically just defines the interface
# and provides a few simple across-the-board functions like 'noop'
class Puppet::Element
    include Puppet
    include Puppet::Util
    include Puppet::Util::Errors
    attr_writer :noop

    class << self
        attr_accessor :doc, :nodoc
        include Puppet::Util
    end

    # all of our subclasses must respond to each of these methods...
    @@interface_methods = [
        :retrieve, :insync?, :sync, :evaluate
    ]

    # so raise an error if a method that isn't overridden gets called
    @@interface_methods.each { |method|
        self.send(:define_method,method) {
            raise Puppet::DevError, "%s has not overridden %s" %
                [self.class.name,method]
        }
    }

    Puppet::Util.logmethods(self, true)

    # for testing whether we should actually do anything
    def noop
        unless defined? @noop
            @noop = false
        end
        return @noop || Puppet[:noop] || false
    end

    # return the full path to us, for logging and rollback
    # some classes (e.g., FileTypeRecords) will have to override this
    def path
        unless defined? @path
            @path = pathbuilder
        end

        return "/" + @path.join("/")
    end
end

# $Id$
