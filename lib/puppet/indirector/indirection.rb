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
        terminus(cache_name)
    end

    # Should we use a cache?
    def cache?
        cache_name ? true : false
    end

    # Figure out the cache name, if there is one.  If there's no name, then
    # caching is disabled.
    def cache_name
        unless @cache_name
            setting_name = "%s_cache" % self.name
            if ! Puppet.settings.valid?(setting_name) or (value = Puppet.settings[setting_name] and value == "none")
                @cache_name = nil
            else
                @cache_name = value
                @cache_name = @cache_name.intern if @cache_name.is_a?(String)
            end
        end
        @cache_name
    end

    # Clear our cached list of termini, and reset the cache name
    # so it's looked up again.
    # This is only used for testing.
    def clear_cache
        @cache_name = nil
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
        @cache_name = nil
        raise(ArgumentError, "Indirection %s is already defined" % @name) if @@indirections.find { |i| i.name == @name }
        @@indirections << self
    end

    # Return the singleton terminus for this indirection.
    def terminus(terminus_name = nil)
        # Get the name of the terminus.
        unless terminus_name
            param_name = "%s_terminus" % self.name
            if Puppet.settings.valid?(param_name)
                terminus_name = Puppet.settings[param_name]
            else
                terminus_name = Puppet[:default_terminus]
            end
            unless terminus_name and terminus_name.to_s != ""
                raise ArgumentError, "Invalid terminus name %s" % terminus_name.inspect
            end
            terminus_name = terminus_name.intern if terminus_name.is_a?(String)
        end
        
        return @termini[terminus_name] ||= make_terminus(terminus_name)
    end

    def find(*args)
        terminus.find(*args)
    end

    def destroy(*args)
        cache.destroy(*args) if cache?
        terminus.destroy(*args)
    end

    def search(*args)
        terminus.search(*args)
    end

    # these become instance methods 
    def save(*args)
        cache.save(*args) if cache?
        terminus.save(*args)
    end

    private

    # Create a new terminus instance.
    def make_terminus(name)
        # Load our terminus class.
        unless klass = Puppet::Indirector::Terminus.terminus_class(name, self.name)
            raise ArgumentError, "Could not find terminus %s for indirection %s" % [name, self.name]
        end
        return klass.new
    end
end
