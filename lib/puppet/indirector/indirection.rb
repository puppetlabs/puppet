require 'puppet/util/docs'
require 'puppet/indirector/envelope'

# The class that connects functional classes with their different collection
# back-ends.  Each indirection has a set of associated terminus classes,
# each of which is a subclass of Puppet::Indirector::Terminus.
class Puppet::Indirector::Indirection
    include Puppet::Util::Docs

    @@indirections = []

    # Clear all cached termini from all indirections.
    def self.clear_cache
        @@indirections.each { |ind| ind.clear_cache }
    end

    # Find an indirection by name.  This is provided so that Terminus classes
    # can specifically hook up with the indirections they are associated with.
    def self.instance(name)
        @@indirections.find { |i| i.name == name }
    end

    # Return a list of all known indirections.  Used to generate the
    # reference.
    def self.instances
        @@indirections.collect { |i| i.name }
    end
    
    # Find an indirected model by name.  This is provided so that Terminus classes
    # can specifically hook up with the indirections they are associated with.
    def self.model(name)
        return nil unless match = @@indirections.find { |i| i.name == name }
        match.model
    end
    
    attr_accessor :name, :model

    # Create and return our cache terminus.
    def cache
        raise(Puppet::DevError, "Tried to cache when no cache class was set") unless cache_class
        terminus(cache_class)
    end

    # Should we use a cache?
    def cache?
        cache_class ? true : false
    end

    attr_reader :cache_class
    # Define a terminus class to be used for caching.
    def cache_class=(class_name)
        validate_terminus_class(class_name)
        @cache_class = class_name
    end

    # Clear our cached list of termini, and reset the cache name
    # so it's looked up again.
    # This is only used for testing.
    def clear_cache
        @termini.clear
    end

    # This is only used for testing.
    def delete
        @@indirections.delete(self) if @@indirections.include?(self)
    end

    # Set the time-to-live for instances created through this indirection.
    def ttl=(value)
        raise ArgumentError, "Indirection TTL must be an integer" unless value.is_a?(Fixnum)
        @ttl = value
    end

    # Default to the runinterval for the ttl.
    def ttl
        unless defined?(@ttl)
            @ttl = Puppet[:runinterval].to_i
        end
        @ttl
    end

    # Calculate the expiration date for a returned instance.
    def expiration
        Time.now + ttl
    end

    # Generate the full doc string.
    def doc
        text = ""

        if defined? @doc and @doc
            text += scrub(@doc) + "\n\n"
        end

        if s = terminus_setting()
            text += "* **Terminus Setting**: %s" % terminus_setting
        end

        text
    end

    def initialize(model, name, options = {})
        @model = model
        @name = name

        @termini = {}
        @cache_class = nil
        @terminus_class = nil

        raise(ArgumentError, "Indirection %s is already defined" % @name) if @@indirections.find { |i| i.name == @name }
        @@indirections << self

        if mod = options[:extend]
            extend(mod)
            options.delete(:extend)
        end

        # This is currently only used for cache_class and terminus_class.
        options.each do |name, value|
            begin
                send(name.to_s + "=", value)
            rescue NoMethodError
                raise ArgumentError, "%s is not a valid Indirection parameter" % name
            end
        end
    end

    # Set the options that can be passed on to the terminus instances.
    attr_reader :option_struct
    def options=(options)
        @option_struct = Struct.new(*options)
    end

    # Return the singleton terminus for this indirection.
    def terminus(terminus_name = nil)
        # Get the name of the terminus.
        unless terminus_name ||= terminus_class
            raise Puppet::DevError, "No terminus specified for %s; cannot redirect" % self.name
        end
        
        return @termini[terminus_name] ||= make_terminus(terminus_name)
    end

    # This can be used to select the terminus class.
    attr_accessor :terminus_setting

    # Determine the terminus class.
    def terminus_class
        unless @terminus_class
            if setting = self.terminus_setting
                self.terminus_class = Puppet.settings[setting].to_sym
            else
                raise Puppet::DevError, "No terminus class nor terminus setting was provided for indirection %s" % self.name
            end
        end
        @terminus_class
    end

    # Specify the terminus class to use.
    def terminus_class=(klass)
        validate_terminus_class(klass)
        @terminus_class = klass
    end

    # This is used by terminus_class= and cache=.
    def validate_terminus_class(terminus_class)
        unless terminus_class and terminus_class.to_s != ""
            raise ArgumentError, "Invalid terminus name %s" % terminus_class.inspect
        end
        unless Puppet::Indirector::Terminus.terminus_class(self.name, terminus_class)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [terminus_class, self.name]
        end
    end

    def find(key, *args)
        # Select the appropriate terminus if there's a hook
        # for doing so.  This allows the caller to pass in some kind
        # of URI that the indirection can use for routing to the appropriate
        # terminus.
        if respond_to?(:select_terminus)
            terminus_name = select_terminus(key, *args)
        else
            terminus_name = terminus_class
        end

        check_authorization(:find, terminus_name, ([key] + args))

        # See if our instance is in the cache and up to date.
        if cache? and cached = cache.find(key, *args)
            if cached.expired?
                Puppet.info "Cached %s %s expired at %s; not using" % [self.name, key, cached.expiration]
            else
                Puppet.debug "Using cached %s %s" % [self.name, key]
                return cached
            end
        end

        # Otherwise, return the result from the terminus, caching if appropriate.
        if result = terminus(terminus_name).find(key, *args)
            # Include the envelope module, so we can set the expiration.
            result.extend(Puppet::Indirector::Envelope)
            result.expiration ||= self.expiration
            if cache?
                Puppet.info "Caching %s %s" % [self.name, key]
                cache.save(result, *args)
            end

            return result
        end

        return nil
    end

    # Remove something via the terminus.
    def destroy(key, *args)
        check_authorization(:destroy, terminus_class, ([key] + args))

        terminus.destroy(key, *args)

        if cache? and cached = cache.find(key, *args)
            cache.destroy(key, *args)
        end

        nil
    end

    # Search for more than one instance.  Should always return an array.
    def search(*args)
        check_authorization(:search, terminus_class, args)

        result = terminus.search(*args)

        result
    end

    # these become instance methods 
    def save(instance, *args)
        if respond_to?(:select_terminus)
            terminus_name = select_terminus(instance.name, *args)
        else
            terminus_name = terminus_class
        end

        check_authorization(:save, terminus_name, ([instance] + args))

        # If caching is enabled, save our document there, do
        cache.save(instance, *args) if cache?
        terminus(terminus_class).save(instance, *args)
    end

    def version(*args)
        terminus.version(*args)
    end

    private

    # Check authorization if there's a hook available; fail if there is one
    # and it returns false.
    def check_authorization(method, terminus_name, arguments)
        # Don't check authorization if there's no node.
        # LAK:FIXME This is a hack and is quite possibly not the design we want.
        return unless arguments[-1].is_a?(Hash) and arguments[-1][:node]

        if terminus(terminus_name).respond_to?(:authorized?) and ! terminus(terminus_name).authorized?(method, *arguments)
            raise ArgumentError, "Not authorized to call %s with %s" % [method, arguments[0]]
        end
    end

    # Handle a given indirected call.
    def prepare_call(method, arguments)
        raise ArgumentError, "Options must be a hash" unless arguments.is_a?(Hash)

        # Set any terminus options.
        options = option_struct ? set_options(option_struct, arguments) : nil

        tclass = choose_terminus(options)

        check_authorization(method, tclass, options)

        return terminus(tclass), options
    end

    # Create a new terminus instance.
    def make_terminus(terminus_class)
        # Load our terminus class.
        unless klass = Puppet::Indirector::Terminus.terminus_class(self.name, terminus_class)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [terminus_class, self.name]
        end
        return klass.new
    end

    # Create a struct instance with all of the appropriate options set
    # from the provided hash.
    def set_options(struct, arguments)
        struct.new(struct.members.inject([]) { |array, param| arguments[param.to_sym]; array } )
    end
end
