class Puppet::Type
    attr_reader :provider

    # the Type class attribute accessors
    class << self
        attr_accessor :providerloader
        attr_writer :defaultprovider
    end

    # Find the default provider.
    def self.defaultprovider
        unless defined? @defaultprovider and @defaultprovider
            suitable = suitableprovider()

            # Find which providers are a default for this system.
            defaults = suitable.find_all { |provider| provider.default? }

            # If we don't have any default we use suitable providers
            defaults = suitable if defaults.empty?
            max = defaults.collect { |provider| provider.defaultnum }.max
            defaults = defaults.find_all { |provider| provider.defaultnum == max }

            retval = nil
            if defaults.length > 1
                Puppet.warning(
                    "Found multiple default providers for %s: %s; using %s" %
                    [self.name, defaults.collect { |i| i.name.to_s }.join(", "),
                        defaults[0].name]
                )
                retval = defaults.shift
            elsif defaults.length == 1
                retval = defaults.shift
            else
                raise Puppet::DevError, "Could not find a default provider for %s" %
                    self.name
            end

            @defaultprovider = retval
        end

        return @defaultprovider
    end

    # Retrieve a provider by name.
    def self.provider(name)
        name = Puppet::Util.symbolize(name)

        # If we don't have it yet, try loading it.
        unless @providers.has_key?(name)
            @providerloader.load(name)
        end
        return @providers[name]
    end

    # Just list all of the providers.
    def self.providers
        @providers.keys
    end

    def self.validprovider?(name)
        name = Puppet::Util.symbolize(name)

        return (@providers.has_key?(name) && @providers[name].suitable?)
    end

    # Create a new provider of a type.  This method must be called
    # directly on the type that it's implementing.
    def self.provide(name, options = {}, &block)
        name = Puppet::Util.symbolize(name)
        model = self

        parent = if pname = options[:parent]
            if pname.is_a? Class
                pname
            else
                if provider = self.provider(pname)
                    provider
                else
                    raise Puppet::DevError,
                        "Could not find parent provider %s of %s" %
                            [pname, name]
                end
            end
        else
            Puppet::Type::Provider
        end

        self.providify

        provider = genclass(name,
            :parent => parent,
            :hash => @providers,
            :prefix => "Provider",
            :block => block,
            :attributes => {
                :model => model
            }
        )

        return provider
    end

    # Make sure we have a :provider parameter defined.  Only gets called if there
    # are providers.
    def self.providify
        return if @paramhash.has_key? :provider
        model = self
        newparam(:provider) do
            desc "The specific backend for #{self.name.to_s} to use. You will
                seldom need to specify this -- Puppet will usually discover the
                appropriate provider for your platform."

            # This is so we can refer back to the type to get a list of
            # providers for documentation.
            class << self
                attr_accessor :parenttype
            end

            # We need to add documentation for each provider.
            def self.doc
                @doc + "  Available providers are:\n\n" + parenttype().providers.sort { |a,b|
                    a.to_s <=> b.to_s
                }.collect { |i|
                    "* **%s**: %s" % [i, parenttype().provider(i).doc]
                }.join("\n")
            end

            defaultto { @parent.class.defaultprovider.name }

            validate do |value|
                value = value[0] if value.is_a? Array
                if provider = @parent.class.provider(value)
                    unless provider.suitable?
                        raise ArgumentError,
                            "Provider '%s' is not functional on this platform" %
                            [value]
                    end
                else
                    raise ArgumentError, "Invalid %s provider '%s'" %
                        [@parent.class.name, value]
                end
            end

            munge do |provider|
                provider = provider[0] if provider.is_a? Array
                if provider.is_a? String
                    provider = provider.intern
                end
                @parent.provider = provider
                provider
            end
        end.parenttype = self
    end

    def self.unprovide(name)
        if @providers.has_key? name
            if @defaultprovider and @defaultprovider.name == name
                @defaultprovider = nil
            end
            @providers.delete(name)
        end
    end

    # Return an array of all of the suitable providers.
    def self.suitableprovider
        @providers.find_all { |name, provider|
            provider.suitable?
        }.collect { |name, provider|
            provider
        }.reject { |p| p.name == :fake } # For testing
    end

    def provider=(name)
        if klass = self.class.provider(name)
            @provider = klass.new(self)
        else
            raise UnknownProviderError, "Could not find %s provider of %s" %
                [name, self.class.name]
        end
    end
end

# $Id$
