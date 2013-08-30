module Puppet::Util::Cacher
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
    def cached_attr(name, ttl, &block)
      init_method = "init_#{name}"
      define_method(init_method, &block)

      set_attr_ttl(name, ttl)

      define_method(name) do
        cached_value(name)
      end

      define_method(name.to_s + "=") do |value|
        # Make sure the cache timestamp is set
        value_cache[name] = value
        set_expiration(name)
      end
    end

    def attr_ttl(name)
      @attr_ttls[name]
    end

    def set_attr_ttl(name, value)
      @attr_ttls ||= {}
      @attr_ttls[name] = Integer(value)
    end
  end

  # Methods that get added to instances.
  module InstanceMethods
    private

    def cached_value(name)
      if value_cache[name].nil? or expired_by_ttl?(name)
        value_cache[name] = send("init_#{name}")
        set_expiration(name)
      end
      value_cache[name]
    end

    def expired_by_ttl?(name)
      @attr_expirations[name] < Time.now
    end

    def set_expiration(name)
      @attr_expirations ||= {}
      @attr_expirations[name] = Time.now + self.class.attr_ttl(name)
    end

    def value_cache
      @value_cache ||= {}
    end
  end
end
