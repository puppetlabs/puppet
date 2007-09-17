# Manage indirections to termini.  They are organized in terms of indirections -
# - e.g., configuration, node, file, certificate -- and each indirection has one
# or more terminus types defined.  The indirection is configured via the
# +indirects+ method, which will be called by the class extending itself
# with this module.
module Puppet::Indirector
    # LAK:FIXME We need to figure out how to handle documentation for the
    # different indirection types.

    # A simple class that can function as the base class for indirected types.
    class Terminus
        require 'puppet/util/docs'
        extend Puppet::Util::Docs

        class << self
            attr_accessor :name, :indirection
        end
        def name
            self.class.name
        end
        def indirection
            self.class.indirection
        end
    end

    require 'puppet/indirector/indirection'

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
    def self.register_indirection(name)
        # Set up autoloading of the appropriate termini.
        instance_load name, "puppet/indirector/%s" % name
    end
    
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
            :parent => options[:parent] || Terminus
        )
        klass.indirection = indirection
        klass.name = terminus
    end

    # Retrieve a terminus class by indirection and name.
    def self.terminus(indirection, terminus)
        loaded_instance(indirection, terminus)
    end

    # Declare that the including class indirects its methods to
    # this terminus.  The terminus name must be the name of a Puppet
    # default, not the value -- if it's the value, then it gets
    # evaluated at parse time, which is before the user has had a chance
    # to override it.
    #   Options are:
    # +:to+: What parameter to use as the name of the indirection terminus.
    def indirects(indirection, options = {})
        if defined?(@indirection)
            raise ArgumentError, "Already performing an indirection of %s; cannot redirect %s" % [@indirection.name, indirection]
        end

        # JRB:  this associates an indirection class with this class (e.g., Node.@indirection = Indirection.new(:node))
        @indirection = Indirection.new(indirection, options)

        # Set up autoloading of the appropriate termini.
        Puppet::Indirector.register_indirection indirection

        extend ClassMethods
        include InstanceMethods
    end

    module InstanceMethods
      # these become instance methods 
      def save
      end
    end
    
    module ClassMethods
      def find
      end

      def destroy
      end

      def search
      end
    end

    # JRB:FIXME: these methods to be deprecated:

    # Define methods for each of the HTTP methods.  These just point to the
    # termini, with consistent error-handling.  Each method is called with
    # the first argument being the indirection type and the rest of the
    # arguments passed directly on to the indirection terminus.  There is
    # currently no attempt to standardize around what the rest of the arguments
    # should allow or include or whatever.
    #   There is also no attempt to pre-validate that a given indirection supports
    # the method in question.  We should probably require that indirections
    # declare supported methods, and then verify that termini implement all of
    # those methods.
    [:get, :post, :put, :delete].each do |method_name|
        define_method(method_name) do |*args|
            redirect(method_name, *args)
        end
    end

    private


    # Redirect one of our methods to the corresponding method on the Terminus
    def redirect(method_name, *args)
        begin
            @indirection.terminus.send(method_name, *args)
        rescue NoMethodError => detail
            puts detail.backtrace if Puppet[:trace]
            raise ArgumentError, "The %s terminus of the %s indirection failed to respond to %s: %s" %
                [@indirection.terminus.name, @indirection.name, method_name, detail]
        end
    end
end
