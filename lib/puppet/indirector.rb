# Manage indirections to termini.  They are organized in terms of indirections -
# - e.g., configuration, node, file, certificate -- and each indirection has one
# or more terminus types defined.  The indirection is configured via the
# +indirects+ method, which will be called by the class extending itself
# with this module.
module Puppet::Indirector
    # LAK:FIXME We need to figure out how to handle documentation for the
    # different indirection types.

# JRB:TODO factor this out into its own class, with specs, and require it here
# require 'puppet/indirector/terminus'

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

# JRB:TODO - where did this come from, re: the specs?  also, shouldn't this be protected/private?
    
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
    
    # clear out the list of known indirections
#JRB:TODO -- I would prefer to get rid of this altogether, but it's implicated in testing, given the class loader
    def self.reset
      @indirections = {}
      @class_indirections = {}
    end
    
    # return a hash of registered indirections, keys are indirection names, values are classes which handle the indirections
    def self.indirections
      @indirections ||= {}
      @indirections
    end
    
    # associate an indirection name with the class which handles the indirection
    def self.register_indirection(name, klass)
      @indirections ||= {}
      @class_indirections ||= {}
      
      raise ArgumentError, "Already performing an indirection of %s; cannot redirect %s" % [name, klass.name] if @indirections[name]
      raise ArgumentError, "Class %s is already redirecting to %s; cannot redirect to %s" % 
        [klass.name, @class_indirections[klass.name], name] if @class_indirections[klass.name]
      @class_indirections[klass.name] = name
      @indirections[name] = klass
    end
    
    def self.terminus_for_indirection(name)
# JRB:TODO make this do something useful, aka look something up in a .yml file
      # JRB:TODO look up name + '_source' in standard configuration
      :ldap
    end

    # Declare that the including class indirects its methods to
    # this terminus.  The terminus name must be the name of a Puppet
    # default, not the value -- if it's the value, then it gets
    # evaluated at parse time, which is before the user has had a chance
    # to override it.
    def indirects(indirection, options = {})
#JRB:TODO remove options hash  ^^^

        # associate the name :node, with this class, Node
        # also, do error checking (already registered, etc.)
        Puppet::Indirector.register_indirection(indirection, self)

        # populate this registered class with the various new methods
        extend ClassMethods
        include InstanceMethods

        # look up the type of Terminus for this name (:node => :ldap)
        terminus = Puppet::Indirector.terminus_for_indirection(indirection)

        # instantiate the actual Terminus for that type and this name (:ldap, w/ args :node)
        # & hook the instantiated Terminus into this registered class (Node: @indirection = terminus)
        Puppet::Indirector.enable_autoloading_indirection indirection
        @indirection = Puppet::Indirector.terminus(indirection, terminus)
    end

    module ClassMethods   
      attr_reader :indirection
         
      def find(*args)
        self.indirection.find(args)
        # JRB:TODO look up the indirection, and call its .find method
      end

      def destroy(*args)
        self.indirection.destroy(args)
      end

      def search(*args)
        self.indirection.search(args)
      end
    end

    module InstanceMethods
      # these become instance methods 
      def save(*args)
        self.class.indirection.save(args)
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
    # [:get, :post, :put, :delete].each do |method_name|
    #     define_method(method_name) do |*args|
    #         redirect(method_name, *args)
    #     end
    # end
    # 
    # private
    # 
    # 
    # # JRB:TODO this needs to be renamed, as it actually ends up on the model class, where it might conflict with something
    # # Redirect one of our methods to the corresponding method on the Terminus
    # def redirect(method_name, *args)
    #     begin
    #         @indirection.terminus.send(method_name, *args)
    #     rescue NoMethodError => detail
    #         puts detail.backtrace if Puppet[:trace]
    #         raise ArgumentError, "The %s terminus of the %s indirection failed to respond to %s: %s" %
    #             [@indirection.terminus.name, @indirection.name, method_name, detail]
    #     end
    # end
end
