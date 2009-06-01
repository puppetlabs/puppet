module Puppet::Util::Cacher
    module Expirer
        attr_reader :timestamp

        # Cause all cached values to be considered expired.
        def expire
            @timestamp = Time.now
        end

        # Is the provided timestamp earlier than our expiration timestamp?
        # If it is, then the associated value is expired.
        def dependent_data_expired?(ts)
            return false unless timestamp

            return timestamp > ts
        end
    end

    extend Expirer

    # Our module has been extended in a class; we can only add the Instance methods,
    # which become *class* methods in the class.
    def self.extended(other)
        class << other
            extend ClassMethods
            include InstanceMethods
        end
    end

    # Our module has been included in a class, which means the class gets the class methods
    # and all of its instances get the instance methods.
    def self.included(other)
        other.extend(ClassMethods)
        other.send(:include, InstanceMethods)
    end

    # Methods that can get added to a class.
    module ClassMethods
        # Provide a means of defining an attribute whose value will be cached.
        # Must provide a block capable of defining the value if it's flushed..
        def cached_attr(name, options = {}, &block)
            init_method = "init_" + name.to_s
            define_method(init_method, &block)

            define_method(name) do
                cached_value(name)
            end

            define_method(name.to_s + "=") do |value|
                # Make sure the cache timestamp is set
                cache_timestamp
                value_cache[name] = value
            end

            if ttl = options[:ttl]
                set_attr_ttl(name, ttl)
            end
        end

        def attr_ttl(name)
            return nil unless defined?(@attr_ttls) and @attr_ttls
            @attr_ttls[name]
        end

        def set_attr_ttl(name, value)
            @attr_ttls ||= {}
            @attr_ttls[name] = Integer(value)
        end
    end

    # Methods that get added to instances.
    module InstanceMethods
        def expire
            # Only expire if we have an expirer.  This is
            # mostly so that we can comfortably handle cases
            # like Puppet::Type instances, which use their
            # catalog as their expirer, and they often don't
            # have a catalog.
            if e = expirer
                e.expire
            end
        end

        def expirer
            Puppet::Util::Cacher
        end

        private

        def cache_timestamp
            unless defined?(@cache_timestamp)
                @cache_timestamp = Time.now
            end
            @cache_timestamp
        end

        def cached_value(name)
            # Allow a nil expirer, in which case we regenerate the value every time.
            if expired_by_expirer?(name)
                value_cache.clear
                @cache_timestamp = Time.now
            elsif expired_by_ttl?(name)
                value_cache.delete(name)
            end
            unless value_cache.include?(name)
                value_cache[name] = send("init_%s" % name)
            end
            value_cache[name]
        end

        def expired_by_expirer?(name)
            if expirer.nil?
                return true unless self.class.attr_ttl(name)
            end
            return expirer.dependent_data_expired?(cache_timestamp)
        end

        def expired_by_ttl?(name)
            return false unless self.class.respond_to?(:attr_ttl)
            return false unless ttl = self.class.attr_ttl(name)

            @ttl_timestamps ||= {}
            @ttl_timestamps[name] ||= Time.now

            return (Time.now - @ttl_timestamps[name]) > ttl
        end

        def value_cache
            unless defined?(@value_cache) and @value_cache
                @value_cache = {}
            end
            @value_cache
        end
    end
end
