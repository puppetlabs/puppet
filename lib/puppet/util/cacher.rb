module Puppet::Util::Cacher
    # Cause all cached values to be considered invalid.
    def self.invalidate
        @timestamp = Time.now
    end

    # Is the provided timestamp later than or equal to our global timestamp?
    # If it is, then the associated value is valid, otherwise it should be flushed.
    def self.valid?(timestamp)
        unless defined?(@timestamp) and @timestamp
            @timestamp = Time.now
            return true
        end
        return timestamp >= @timestamp
    end

    # Our module has been extended in a class; we can only add the Instance methods,
    # which become *class* methods in the class.
    def self.extended(other)
        other.extend(InstanceMethods)
    end

    # Our module has been included in a class, which means the class gets the class methods
    # and all of its instances get the instance methods.
    def self.included(other)
        other.extend(ClassMethods)
        other.send(:include, InstanceMethods)
    end

    # Methods that can get added to a class.
    module ClassMethods
        private

        # Provide a means of defining an attribute whose value will be cached.
        # Must provide a block capable of defining the value if it's flushed..
        def cached_attr(name, &block)
            define_method(name) do
                attr_cache(name, &block)
            end
        end
    end

    # Methods that get added to instances.
    module InstanceMethods
        private

        # Use/define a cached value.  We just use the Cache class to do all
        # of the thinking.  Note that we're using a single Cache instance
        # for all of this instance's cached values.
        def attr_cache(name, &block)
            unless defined?(@cacher_caches) and @cacher_caches
                @cacher_caches = Cache.new
            end

            @cacher_caches.value(name, &block)
        end
    end

    # An internal class that does all of our comparisons and calculations.
    # This both caches a given value, and determines whether a given cache is
    # still valid.
    class Cache
        attr_accessor :caches, :timestamp

        def initialize
            @caches = {}
        end

        # Return a value; use the cached version if the associated timestamp is recent enough,
        # else calculate and store a new a value using the provided block.
        def value(name)
            raise ArgumentError, "You must provide a block when using the cache" unless block_given?

            # If we have no timestamp (because this is the first run) or our
            # timestamp is out of date, clear the cache and get a new value.
            # Note that if we clear the cache here, we potentially clear other
            # cached values, too (if this instance is caching more than one value).
            if timestamp.nil? or ! Puppet::Util::Cacher.valid?(timestamp)
                caches.clear
                self.timestamp = Time.now
            end

            # Generate a new value if we don't have one.  Use 'include?' here
            # rather than testing for truth, so we can cache false values.
            unless caches.include?(name)
                caches[name] = yield
            end

            # Finally, return our cached value.
            caches[name]
        end
    end
end
