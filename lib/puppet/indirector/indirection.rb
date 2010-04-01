require 'puppet/util/docs'
require 'puppet/indirector/envelope'
require 'puppet/indirector/request'
require 'puppet/util/cacher'

# The class that connects functional classes with their different collection
# back-ends.  Each indirection has a set of associated terminus classes,
# each of which is a subclass of Puppet::Indirector::Terminus.
class Puppet::Indirector::Indirection
    include Puppet::Util::Cacher
    include Puppet::Util::Docs

    @@indirections = []

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
        validate_terminus_class(class_name) if class_name
        @cache_class = class_name
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

    # Set up our request object.
    def request(method, key, arguments = nil)
        Puppet::Indirector::Request.new(self.name, method, key, arguments)
    end

    # Return the singleton terminus for this indirection.
    def terminus(terminus_name = nil)
        # Get the name of the terminus.
        unless terminus_name ||= terminus_class
            raise Puppet::DevError, "No terminus specified for %s; cannot redirect" % self.name
        end

        return termini[terminus_name] ||= make_terminus(terminus_name)
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

    def reset_terminus_class
        @terminus_class = nil
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

    # Expire a cached object, if one is cached.  Note that we don't actually
    # remove it, we expire it and write it back out to disk.  This way people
    # can still use the expired object if they want.
    def expire(key, *args)
        request = request(:expire, key, *args)

        return nil unless cache?

        return nil unless instance = cache.find(request(:find, key, *args))

        Puppet.info "Expiring the %s cache of %s" % [self.name, instance.name]

        # Set an expiration date in the past
        instance.expiration = Time.now - 60

        cache.save(request(:save, instance, *args))
    end

    # Search for an instance in the appropriate terminus, caching the
    # results if caching is configured..
    def find(key, *args)
        request = request(:find, key, *args)
        terminus = prepare(request)

        begin
            if result = find_in_cache(request)
                return result
            end
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Cached %s for %s failed: %s" % [self.name, request.key, detail]
        end

        # Otherwise, return the result from the terminus, caching if appropriate.
        if ! request.ignore_terminus? and result = terminus.find(request)
            result.expiration ||= self.expiration
            if cache? and request.use_cache?
                Puppet.info "Caching %s for %s" % [self.name, request.key]
                cache.save request(:save, result, *args)
            end

            return terminus.respond_to?(:filter) ? terminus.filter(result) : result
        end

        return nil
    end

    def find_in_cache(request)
        # See if our instance is in the cache and up to date.
        return nil unless cache? and ! request.ignore_cache? and cached = cache.find(request)
        if cached.expired?
            Puppet.info "Not using expired %s for %s from cache; expired at %s" % [self.name, request.key, cached.expiration]
            return nil
        end

        Puppet.debug "Using cached %s for %s" % [self.name, request.key]
        return cached
    end

    # Remove something via the terminus.
    def destroy(key, *args)
        request = request(:destroy, key, *args)
        terminus = prepare(request)

        result = terminus.destroy(request)

        if cache? and cached = cache.find(request(:find, key, *args))
            # Reuse the existing request, since it's equivalent.
            cache.destroy(request)
        end

        result
    end

    # Search for more than one instance.  Should always return an array.
    def search(key, *args)
        request = request(:search, key, *args)
        terminus = prepare(request)

        if result = terminus.search(request)
            raise Puppet::DevError, "Search results from terminus %s are not an array" % terminus.name unless result.is_a?(Array)
            result.each do |instance|
                instance.expiration ||= self.expiration
            end
            return result
        end
    end

    # Save the instance in the appropriate terminus.  This method is
    # normally an instance method on the indirected class.
    def save(instance, *args)
        request = request(:save, instance, *args)
        terminus = prepare(request)

        result = terminus.save(request)

        # If caching is enabled, save our document there
        cache.save(request) if cache?

        result
    end

    private

    # Check authorization if there's a hook available; fail if there is one
    # and it returns false.
    def check_authorization(request, terminus)
        # At this point, we're assuming authorization makes no sense without
        # client information.
        return unless request.node

        # This is only to authorize via a terminus-specific authorization hook.
        return unless terminus.respond_to?(:authorized?)

        unless terminus.authorized?(request)
            msg = "Not authorized to call %s on %s" % [request.method, request.to_s]
            unless request.options.empty?
                msg += " with %s" % request.options.inspect
            end
            raise ArgumentError, msg
        end
    end

    # Setup a request, pick the appropriate terminus, check the request's authorization, and return it.
    def prepare(request)
        # Pick our terminus.
        if respond_to?(:select_terminus)
            unless terminus_name = select_terminus(request)
                raise ArgumentError, "Could not determine appropriate terminus for %s" % request
            end
        else
            terminus_name = terminus_class
        end

        dest_terminus = terminus(terminus_name)
        check_authorization(request, dest_terminus)

        return dest_terminus
    end

    # Create a new terminus instance.
    def make_terminus(terminus_class)
        # Load our terminus class.
        unless klass = Puppet::Indirector::Terminus.terminus_class(self.name, terminus_class)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [terminus_class, self.name]
        end
        return klass.new
    end

    # Cache our terminus instances indefinitely, but make it easy to clean them up.
    cached_attr(:termini) { Hash.new }
end
