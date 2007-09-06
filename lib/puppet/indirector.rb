# Manage indirections to termini.  They are organized in terms of indirections -
# - e.g., configuration, node, file, certificate -- and each indirection has one
# or more terminus types defined.  The indirection must have its preferred terminus
# configured via a 'default' in the form of '<indirection>_terminus'; e.g.,
# 'node_terminus = ldap'.
class Puppet::Indirector
    # A simple indirection category.  Indirections are the things that can have
    # multiple indirect termini, like node, configuration, or facts.  Indirections
    # should be very low-configuration, and at this point they don't do much beyond
    # define the valid indirection categories.
    class Indirection
        attr_accessor :name, :default

        def initialize(name)
            @name = name
            options.each { |param, val| send(param.to_s + "=", val) }
        end

        def to_s
            @name.to_s
        end
    end

    # This manages reading in all of our files for us and then retrieving
    # loaded instances.  We still have to define the 'newX' method, but this
    # does all of the rest -- loading, storing, and retrieving by name.
    require 'puppet/util/instance_loader'
    extend Puppet::Util::InstanceLoader

    # Autoload our indirections.  Each indirection will set up its own autoloader.
    # Indirections have to be stored by name at this path.
    autoload :indirection, "puppet/indirector"

    # Return (and load, if necessary) a specific autoloaded indirection.
    def self.indirection(name)
        loaded_instance(:indirection, name)
    end

    # Define a new indirection.  This method is used in the indirection files
    # to define a new indirection category.
    def self.newindirection(name, options = {}, &block)
        unless Puppet.config.valid?("%s_terminus" % name)
            raise ArgumentError, "Indirection category %s does not have a default defined" % name
        end
        # Create the indirection
        @indirections[name] = Indirection.new(name, options)

        # Set its default terminus.
        @indirections[name].default = Puppet.config["%s_terminus" % name]

        # Define a new autoload mechanism for this specific indirection.
        autoload name, "puppet/indirector/%s" % name
    end

    # Define a new indirection terminus.  This method is used by the individual
    # termini in their separate files.  Again, the autoloader takes care of
    # actually loading these files.
    def self.newterminus(indirection, name, options = {}, &block)
        genclass(name, :hash => instance_hash(indirection.name), :attributes => options, :block => block)
    end

    # Retrieve a terminus class by indirection and name.
    def self.terminus(indirection, name)
        loaded_instance(indirection.name, name)
    end

    # Create/return our singleton.
    def self.create
        unless defined? @instance
            @instance = new
        end
        @instance
    end

    # Make sure they have to use the singleton-style method.
    private :new

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
        define_method(method_name) do |cat_name, *args|
            begin
                terminus(self.class.indirection(cat_name)).send(method_name, *args)
            rescue NoMethodError
                raise ArgumentError, "Indirection category %s does not respond to REST method %s" % [indirection, method_name]
            end
        end
    end

    def initialize
        # To hold the singleton termini, by indirection name.
        @termini = {}
    end

    private

    # Create a new terminus instance.
    def make_terminus(indirection)
        # Load our terminus class.
        unless klass = self.class.terminus(indirection, indirection.default)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [indirection.default, indirection]
        end
        return klass.new
    end

    # Return the singleton terminus for this indirection.
    def terminus(indirection)
        unless terminus = @termini[indirection.name]
            terminus = @termini[indirection.name] = make_terminus(indirection)
        end
        terminus
    end
end
