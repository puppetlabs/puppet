require 'puppet/provider'
require 'puppet/util/provider_features'
class Puppet::Type
    # Add the feature handling module.
    extend Puppet::Util::ProviderFeatures

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

    # Convert a hash, as provided by, um, a provider, into an instance of self.
    def self.hash2obj(hash)
        obj = nil
        
        namevar = self.namevar
        unless hash.include?(namevar) and hash[namevar]
            raise Puppet::DevError, "Hash was not passed with namevar"
        end

        # if the obj already exists with that name...
        if obj = self[hash[namevar]]
            # We're assuming here that objects with the same name
            # are the same object, which *should* be the case, assuming
            # we've set up our naming stuff correctly everywhere.

            # Mark found objects as present
            hash.each { |param, value|
                if property = obj.property(param)
                elsif val = obj[param]
                    obj[param] = val
                else
                    # There is a value on disk, but it should go away
                    obj[param] = :absent
                end
            }
        else
            # create a new obj, since no existing one seems to
            # match
            obj = self.create(namevar => hash[namevar])

            # We can't just pass the hash in at object creation time,
            # because it sets the should value, not the is value.
            hash.delete(namevar)
            hash.each { |param, value|
                obj[param] = value unless obj.add_property_parameter(param)
            }
        end

        return obj
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

        if obj = @providers[name]
            Puppet.debug "Reloading %s %s provider" % [name, self.name]
            unprovide(name)
        end

        parent = if pname = options[:parent]
            options.delete(:parent)
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
            Puppet::Provider
        end

        options[:resource_type] ||= self

        self.providify

        provider = genclass(name,
            :parent => parent,
            :hash => @providers,
            :prefix => "Provider",
            :block => block,
            :include => feature_module,
            :extend => feature_module,
            :attributes => options
        )

        return provider
    end

    # Make sure we have a :provider parameter defined.  Only gets called if there
    # are providers.
    def self.providify
        return if @paramhash.has_key? :provider

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

            defaultto {
                @resource.class.defaultprovider.name
            }

            validate do |provider_class|
                provider_class = provider_class[0] if provider_class.is_a? Array
                if provider_class.is_a?(Puppet::Provider)
                    provider_class = provider_class.class.name
                end

                unless provider = @resource.class.provider(provider_class)
                    raise ArgumentError, "Invalid %s provider '%s'" % [@resource.class.name, provider_class]
                end
            end

            munge do |provider|
                provider = provider[0] if provider.is_a? Array
                if provider.is_a? String
                    provider = provider.intern
                end
                @resource.provider = provider

                if provider.is_a?(Puppet::Provider)
                    provider.class.name
                else
                    provider
                end
            end
        end.parenttype = self
    end

    def self.unprovide(name)
        if @providers.has_key? name
            rmclass(name,
                :hash => @providers,
                :prefix => "Provider"
            )
            if @defaultprovider and @defaultprovider.name == name
                @defaultprovider = nil
            end
        end
    end

    # Return an array of all of the suitable providers.
    def self.suitableprovider
        if @providers.empty?
            providerloader.loadall
        end
        @providers.find_all { |name, provider|
            provider.suitable?
        }.collect { |name, provider|
            provider
        }.reject { |p| p.name == :fake } # For testing
    end

    def provider=(name)
        if name.is_a?(Puppet::Provider)
            @provider = name
            @provider.resource = self
        elsif klass = self.class.provider(name)
            @provider = klass.new(self)
        else
            raise ArgumentError, "Could not find %s provider of %s" %
                [name, self.class.name]
        end
    end
end
