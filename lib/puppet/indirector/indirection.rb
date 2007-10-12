# An actual indirection.
class Puppet::Indirector::Indirection
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

    def initialize(model, name, options = {})
        @model = model
        @name = name
        options.each do |name, value|
            begin
                send(name.to_s + "=", value)
            rescue NoMethodError
                raise ArgumentError, "%s is not a valid Indirection parameter" % name
            end
        end
        @termini = {}
        @terminus_types = {}
        @cache_class = nil
        raise(ArgumentError, "Indirection %s is already defined" % @name) if @@indirections.find { |i| i.name == @name }
        @@indirections << self
    end

    # Return the singleton terminus for this indirection.
    def terminus(terminus_name = nil)
        # Get the name of the terminus.
        unless terminus_name ||= terminus_class
            raise Puppet::DevError, "No terminus specified for %s; cannot redirect" % self.name
        end
        
        return @termini[terminus_name] ||= make_terminus(terminus_name)
    end

    attr_reader :terminus_class

    # Specify the terminus class to use.
    def terminus_class=(terminus_class)
        validate_terminus_class(terminus_class)
        @terminus_class = terminus_class
    end

    # This is used by terminus_class= and cache=.
    def validate_terminus_class(terminus_class)
        unless terminus_class and terminus_class.to_s != ""
            raise ArgumentError, "Invalid terminus name %s" % terminus_class.inspect
        end
        unless Puppet::Indirector::Terminus.terminus_class(terminus_class, self.name)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [terminus_class, self.name]
        end
    end

    def find(key, *args)
        if cache? and cache.has_most_recent?(key, terminus.version(key))
            Puppet.info "Using cached %s %s" % [self.name, key]
            return cache.find(key, *args)
        end
        if result = terminus.find(key, *args)
            result.version ||= Time.now.utc
            if cache?
                Puppet.info "Caching %s %s" % [self.name, key]
                cache.save(result, *args)
            end
            return result
        end
    end

    def destroy(*args)
        terminus.destroy(*args)
    end

    def search(*args)
        terminus.search(*args)
    end

    # these become instance methods 
    def save(instance, *args)
        instance.version ||= Time.now.utc
        dest = cache? ? cache : terminus
        return if dest.has_most_recent?(instance.name, instance.version)
        Puppet.info "Caching %s %s" % [self.name, instance.name] if cache?
        cache.save(instance, *args) if cache?
        terminus.save(instance, *args)
    end

    def version(*args)
        terminus.version(*args)
    end

    private

    # Create a new terminus instance.
    def make_terminus(terminus_class)
        # Load our terminus class.
        unless klass = Puppet::Indirector::Terminus.terminus_class(terminus_class, self.name)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [terminus_class, self.name]
        end
        return klass.new
    end
end
