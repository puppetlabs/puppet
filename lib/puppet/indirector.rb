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

    # This handles creating the terminus classes.
    require 'puppet/util/classgen'
    extend Puppet::Util::ClassGen

    # This manages reading in all of our files for us and then retrieving
    # loaded instances.  We still have to define the 'newX' method, but this
    # does all of the rest -- loading, storing, and retrieving by name.
    require 'puppet/util/instance_loader'
    extend Puppet::Util::InstanceLoader
    
    # Register a given indirection type.  The classes including this module
    # handle creating terminus instances, but the module itself handles
    # loading them and managing the classes.
    def self.enable_autoloading_indirection(indirection)
        # Set up autoloading of the appropriate termini.
        instance_load indirection, "puppet/indirector/%s" % indirection
    end
    
# JRB:TODO -- where did this come from, re: the specs? also, any way to make this protected/private?
    
    # Define a new indirection terminus.  This method is used by the individual
    # termini in their separate files.  Again, the autoloader takes care of
    # actually loading these files.
    #   Note that the termini are being registered on the Indirector module, not
    # on the classes including the module.  This allows a given indirection to
    # be used in multiple classes.
    def self.register_terminus(indirection, terminus, options = {}, &block)
        klass = genclass(terminus,
            :prefix => indirection.to_s.capitalize,
            :hash => instance_hash(indirection),
            :attributes => options,
            :block => block,
            :parent => options[:parent] || Terminus,
# JRB:FIXME -- why do I have to use overwrite here?            
            :overwrite => 'please do motherfucker'
        )
        klass.indirection = indirection
        klass.name = terminus
    end

# JRB:TODO where did this come from, re: the specs?  also, shouldn't this be protected/private?    
    # Retrieve a terminus class by indirection and name.
# JRB:FIXME -- should be protected/private
    def self.terminus(indirection, terminus)
        loaded_instance(indirection, terminus)
    end

    # Declare that the including class indirects its methods to
    # this terminus.  The terminus name must be the name of a Puppet
    # default, not the value -- if it's the value, then it gets
    # evaluated at parse time, which is before the user has had a chance
    # to override it.
    def indirects(indirection)
        raise(ArgumentError, "Already handling indirection for %s; cannot also handle %s" % [@indirection.name, indirection]) if defined?(@indirection) and indirection
        # populate this class with the various new methods
        extend ClassMethods
        include InstanceMethods

        # instantiate the actual Terminus for that type and this name (:ldap, w/ args :node)
        # & hook the instantiated Terminus into this class (Node: @indirection = terminus)
        Puppet::Indirector.enable_autoloading_indirection indirection
        @indirection = Puppet::Indirector::Indirection.new(indirection)
    end

    module ClassMethods   
      attr_reader :indirection
         
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
      # these become instance methods 
      def save(*args)
        self.class.indirection.save(self, *args)
      end
    end
end
