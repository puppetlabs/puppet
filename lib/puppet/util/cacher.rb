module Puppet::Util::Cacher
    # Cause all cached values to be considered invalid.
    def self.invalidate
        @timestamp = Time.now
    end

    def self.valid?(timestamp)
        unless defined?(@timestamp) and @timestamp
            @timestamp = Time.now
            return true
        end
        return timestamp >= @timestamp
    end

    def self.extended(other)
        other.extend(InstanceMethods)
    end

    def self.included(other)
        other.extend(ClassMethods)
        other.send(:include, InstanceMethods)
    end

    module ClassMethods
        private

        def cached_attr(name, &block)
            define_method(name) do
                cache(name, &block)
            end
        end
    end

    module InstanceMethods
        private

        def cache(name, &block)
            unless defined?(@cacher_caches) and @cacher_caches
                @cacher_caches = Cache.new
            end

            @cacher_caches.value(name, &block)
        end
    end

    class Cache
        attr_reader :timestamp, :caches

        def initialize
            @timestamp = Time.now
            @caches = {}
        end

        def value(name)
            raise ArgumentError, "You must provide a block when using the cache" unless block_given?

            @caches.clear unless Puppet::Util::Cacher.valid?(@timestamp)

            # Use 'include?' here rather than testing for truth, so we
            # can cache false values.
            unless @caches.include?(name)
                @caches[name] = yield
            end
            @caches[name]
        end
    end
end
