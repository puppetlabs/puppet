# All of the provider plumbing for the resource types.

module Puppet
  class Type
    require 'puppet/provider'
    require 'puppet/util/provider_features'

    # Add the feature handling module.
    extend Puppet::Util::ProviderFeatures

    # The provider that has been selected for the instance of the resource type.
    # @return [Puppet::Provider,nil] the selected provider or nil, if none has been selected
    #
    attr_reader :provider

    # the Type class attribute accessors
    class << self
      # The loader of providers to use when loading providers from disk.
      # Although it looks like this attribute provides a way to operate with different loaders of
      # providers that is not the case; the attribute is written when a new type is created,
      # and should not be changed thereafter.
      # @api private
      #
      attr_accessor :providerloader

      # @todo Don't know if this is a name, or a reference to a Provider instance (now marked up as an instance
      #   of Provider.
      # @return [Puppet::Provider, nil] The default provider for this type, or nil if non is defines
      #
      attr_writer :defaultprovider
    end

    # The default provider, or the most suitable provider if no default provider was set.
    # @note a warning will be issued if no default provider has been configured and a search for the most
    #   suitable provider returns more than one equally suitable provider.
    # @return [Puppet::Provider, nil] the default or most suitable provider, or nil if no provider was found
    #
    def self.defaultprovider
      return @defaultprovider if @defaultprovider

      suitable = suitableprovider

      # Find which providers are a default for this system.
      defaults = suitable.find_all { |provider| provider.default? }

      # If we don't have any default we use suitable providers
      defaults = suitable if defaults.empty?
      max = defaults.collect { |provider| provider.specificity }.max
      defaults = defaults.find_all { |provider| provider.specificity == max }

      if defaults.length > 1
        Puppet.warning(
            "Found multiple default providers for #{self.name}: #{defaults.collect { |i| i.name.to_s }.join(", ")}; using #{defaults[0].name}"
        )
      end

      @defaultprovider = defaults.shift unless defaults.empty?
    end

    # @return [Hash{??? => Puppet::Provider}] Returns a hash of WHAT EXACTLY for the given type
    # @todo what goes into this hash?
    def self.provider_hash_by_type(type)
      @provider_hashes ||= {}
      @provider_hashes[type] ||= {}
    end

    # @return [Hash{ ??? => Puppet::Provider}] Returns a hash of WHAT EXACTLY for this type.
    # @see provider_hash_by_type method to get the same for some other type
    def self.provider_hash
      Puppet::Type.provider_hash_by_type(self.name)
    end

    # Returns the provider having the given name.
    # This will load a provider if it is not already loaded. The returned provider is the first found provider
    # having the given name, where "first found" semantics is defined by the {providerloader} in use.
    #
    # @param name [String] the name of the provider to get
    # @return [Puppet::Provider, nil] the found provider, or nil if no provider of the given name was found
    #
    def self.provider(name)
      name = name.intern

      # If we don't have it yet, try loading it.
      @providerloader.load(name) unless provider_hash.has_key?(name)
      provider_hash[name]
    end

    # Returns a list of loaded providers by name.
    # This method will not load/search for available providers.
    # @return [Array<String>] list of loaded provider names
    #
    def self.providers
      provider_hash.keys
    end

    # Returns true if the given name is a reference to a provider and if this is a suitable provider for
    # this type.
    # @todo How does the provider know if it is suitable for the type? Is it just suitable for the platform/
    #   environment where this method is executing?
    # @param name [String] the name of the provider for which validity is checked
    # @return [Boolean] true if the given name references a provider that is suitable
    #
    def self.validprovider?(name)
      name = name.intern

      (provider_hash.has_key?(name) && provider_hash[name].suitable?)
    end

    # Creates a new provider of a type.
    # This method must be called directly on the type that it's implementing.
    # @todo Fix Confusing Explanations!
    #   Is this a new provider of a Type (metatype), or a provider of an instance of Type (a resource), or
    #   a Provider (the implementation of a Type's behavior). CONFUSED. It calls magically named methods like
    #   "providify" ...
    # @param name [String, Symbol] the name of the WHAT? provider? type?
    # @param options [Hash{Symbol => Object}] a hash of options, used by this method, and passed on to {#genclass}, (see
    #   it for additional options to pass).
    # @option options [Puppet::Provider] :parent the parent provider (what is this?)
    # @option options [Puppet::Type] :resource_type the resource type, defaults to this type if unspecified
    # @return [Puppet::Provider] a provider ???
    # @raise [Puppet::DevError] when the parent provider could not be found.
    #
    def self.provide(name, options = {}, &block)
      name = name.intern

      if unprovide(name)
        Puppet.debug "Reloading #{name} #{self.name} provider"
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
                           "Could not find parent provider #{pname} of #{name}"
                   end
                 end
               else
                 Puppet::Provider
               end

      options[:resource_type] ||= self

      self.providify

      provider = genclass(
          name,
          :parent     => parent,
          :hash       => provider_hash,
          :prefix     => "Provider",
          :block      => block,
          :include    => feature_module,
          :extend     => feature_module,
          :attributes => options
      )

      provider
    end

    # Ensures there is a `:provider` parameter defined.
    # Should only be called if there are providers.
    # @return [void]
    def self.providify
      return if @paramhash.has_key? :provider

      param = newparam(:provider) do
        # We're using a hacky way to get the name of our type, since there doesn't
        # seem to be a correct way to introspect this at the time this code is run.
        # We expect that the class in which this code is executed will be something
        # like Puppet::Type::Ssh_authorized_key::ParameterProvider.
        desc <<-EOT
            The specific backend to use for this `#{self.to_s.split('::')[2].downcase}`
            resource. You will seldom need to specify this --- Puppet will usually
            discover the appropriate provider for your platform.
        EOT

        # This is so we can refer back to the type to get a list of
        # providers for documentation.
        class << self
          # The reference to a parent type for the parameter `:provider` used to get a list of
          # providers for documentation purposes.
          #
          attr_accessor :parenttype
        end

        # Provides the ability to add documentation to a provider.
        #
        def self.doc
          # Since we're mixing @doc with text from other sources, we must normalize
          # its indentation with scrub. But we don't need to manually scrub the
          # provider's doc string, since markdown_definitionlist sanitizes its inputs.
          scrub(@doc) + "Available providers are:\n\n" + parenttype.providers.sort { |a,b|
            a.to_s <=> b.to_s
          }.collect { |i|
            markdown_definitionlist( i, scrub(parenttype().provider(i).doc) )
          }.join
        end

        # For each resource, the provider param defaults to
        # the type's default provider
        defaultto {
          prov = @resource.class.defaultprovider
          prov.name if prov
        }

        validate do |provider_class|
          provider_class = provider_class[0] if provider_class.is_a? Array
          provider_class = provider_class.class.name if provider_class.is_a?(Puppet::Provider)

          unless @resource.class.provider(provider_class)
            raise ArgumentError, "Invalid #{@resource.class.name} provider '#{provider_class}'"
          end
        end

        munge do |provider|
          provider = provider[0] if provider.is_a? Array
          provider = provider.intern if provider.is_a? String
          @resource.provider = provider

          if provider.is_a?(Puppet::Provider)
            provider.class.name
          else
            provider
          end
        end
      end
      param.parenttype = self
    end

    # @todo this needs a better explanation
    # Removes the implementation class of a given provider.
    # @return [Object] returns what {Puppet::Util::ClassGen#rmclass} returns
    def self.unprovide(name)
      if @defaultprovider and @defaultprovider.name == name
        @defaultprovider = nil
      end

      rmclass(name, :hash => provider_hash, :prefix => "Provider")
    end

    # Returns a list of suitable providers for the given type.
    # A call to this method will load all providers if not already loaded and ask each if it is
    # suitable - those that are are included in the result.
    # @note This method also does some special processing which rejects a provider named `:fake` (for testing purposes).
    # @return [Array<Puppet::Provider>] Returns an array of all suitable providers.
    #
    def self.suitableprovider
      providerloader.loadall if provider_hash.empty?
      provider_hash.find_all { |name, provider|
        provider.suitable?
      }.collect { |name, provider|
        provider
      }.reject { |p| p.name == :fake } # For testing
    end

    # @return [Boolean] Returns true if this is something else than a `:provider`, or if it
    #   is a provider and it is suitable, or if there is a default provider. Otherwise, false is returned.
    #
    def suitable?
      # If we don't use providers, then we consider it suitable.
      return true unless self.class.paramclass(:provider)

      # We have a provider and it is suitable.
      return true if provider && provider.class.suitable?

      # We're using the default provider and there is one.
      if !provider and self.class.defaultprovider
        self.provider = self.class.defaultprovider.name
        return true
      end

      # We specified an unsuitable provider, or there isn't any suitable
      # provider.
      false
    end

    # Sets the provider to the given provider/name.
    # @overload provider=(name)
    #   Sets the provider to the result of resolving the name to an instance of Provider.
    #   @param name [String] the name of the provider
    # @overload provider=(provider)
    #   Sets the provider to the given instances of Provider.
    #   @param provider [Puppet::Provider] the provider to set
    # @return [Puppet::Provider] the provider set
    # @raise [ArgumentError] if the provider could not be found/resolved.
    #
    def provider=(name)
      if name.is_a?(Puppet::Provider)
        @provider = name
        @provider.resource = self
      elsif klass = self.class.provider(name)
        @provider = klass.new(self)
      else
        raise ArgumentError, "Could not find #{name} provider of #{self.class.name}"
      end
    end

    # Returns a list of one suitable provider per source, with the default provider first.
    # @todo Needs better explanation; what does "source" mean in this context?
    # @return [Array<Puppet::Provider>] list of providers
    #
    def self.providers_by_source
      # Put the default provider first (can be nil), then the rest of the suitable providers.
      sources = []
      [defaultprovider, suitableprovider].flatten.uniq.collect do |provider|
        next if provider.nil?
        next if sources.include?(provider.source)

        sources << provider.source
        provider
      end.compact
    end
  end
end