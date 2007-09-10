# Manage indirections to termini.  They are organized in terms of indirections -
# - e.g., configuration, node, file, certificate -- and each indirection has one
# or more terminus types defined.  The indirection must have its preferred terminus
# configured via a 'default' in the form of '<indirection>_terminus'; e.g.,
# 'node_terminus = ldap'.
module Puppet::Indirector
    # This manages reading in all of our files for us and then retrieving
    # loaded instances.  We still have to define the 'newX' method, but this
    # does all of the rest -- loading, storing, and retrieving by name.
    require 'puppet/util/instance_loader'
    include Puppet::Util::InstanceLoader

    # Define a new indirection terminus.  This method is used by the individual
    # termini in their separate files.  Again, the autoloader takes care of
    # actually loading these files.
    def register_terminus(name, options = {}, &block)
        genclass(name, :hash => instance_hash(indirection.name), :attributes => options, :block => block)
    end

    # Retrieve a terminus class by indirection and name.
    def terminus(name)
        loaded_instance(name)
    end

    # Declare that the including class indirects its methods to
    # this terminus.  The terminus name must be the name of a Puppet
    # default, not the value -- if it's the value, then it gets
    # evaluated at parse time, which is before the user has had a chance
    # to override it.
    def indirects(indirection, options)
        @indirection = indirection
        @indirect_terminus = options[:to]

        # Set up autoloading of the appropriate termini.
        autoload "puppet/indirector/%s" % indirection
    end

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
            begin
                terminus.send(method_name, *args)
            rescue NoMethodError
                raise ArgumentError, "Indirection category %s does not respond to REST method %s" % [indirection, method_name]
            end
        end
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
    def terminus
        unless terminus = @termini[indirection.name]
            terminus = @termini[indirection.name] = make_terminus(indirection)
        end
        terminus
    end
end
