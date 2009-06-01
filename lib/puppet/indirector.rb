# Manage indirections to termini.  They are organized in terms of indirections -
# - e.g., configuration, node, file, certificate -- and each indirection has one
# or more terminus types defined.  The indirection is configured via the
# +indirects+ method, which will be called by the class extending itself
# with this module.
module Puppet::Indirector
    # LAK:FIXME We need to figure out how to handle documentation for the
    # different indirection types.

    require 'puppet/indirector/indirection'
    require 'puppet/indirector/terminus'
    require 'puppet/indirector/envelope'
    require 'puppet/network/format_handler'

    # Declare that the including class indirects its methods to
    # this terminus.  The terminus name must be the name of a Puppet
    # default, not the value -- if it's the value, then it gets
    # evaluated at parse time, which is before the user has had a chance
    # to override it.
    def indirects(indirection, options = {})
        raise(ArgumentError, "Already handling indirection for %s; cannot also handle %s" % [@indirection.name, indirection]) if defined?(@indirection) and @indirection
        # populate this class with the various new methods
        extend ClassMethods
        include InstanceMethods
        include Puppet::Indirector::Envelope
        extend Puppet::Network::FormatHandler

        # instantiate the actual Terminus for that type and this name (:ldap, w/ args :node)
        # & hook the instantiated Terminus into this class (Node: @indirection = terminus)
        @indirection = Puppet::Indirector::Indirection.new(self, indirection,  options)
        @indirection
    end

    module ClassMethods   
        attr_reader :indirection

        def cache_class=(klass)
            indirection.cache_class = klass
        end

        def terminus_class=(klass)
            indirection.terminus_class = klass
        end
         
        # Expire any cached instance.
        def expire(*args)
            indirection.expire(*args)
        end
         
        def find(*args)
            indirection.find(*args)
        end

        def destroy(*args)
            indirection.destroy(*args)
        end

        def search(*args)
            indirection.search(*args)
        end
    end

    module InstanceMethods
        def save(*args)
            self.class.indirection.save self, *args
        end
    end
end
