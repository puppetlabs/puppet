# -*- coding: utf-8 -*-

module Puppet
  class Type
    # Retrieves all known instances.
    # @todo Retrieves them from where? Known to whom?
    # Either requires providers or must be overridden.
    # @raise [Puppet::DevError] when there are no providers and the implementation has not overridden this method.
    def self.instances
      raise Puppet::DevError, "#{self.name} has no providers and has not overridden 'instances'" if provider_hash.empty?

      # Put the default provider first, then the rest of the suitable providers.
      provider_instances = {}
      providers_by_source.collect do |provider|
        self.properties.find_all do |property|
          provider.supports_parameter?(property)
        end.collect do |property|
          property.name
        end

        provider.instances.collect do |instance|
          # We always want to use the "first" provider instance we find, unless the resource
          # is already managed and has a different provider set
          if other = provider_instances[instance.name]
            Puppet.debug "%s %s found in both %s and %s; skipping the %s version" %
                             [self.name.to_s.capitalize, instance.name, other.class.name, instance.class.name, instance.class.name]
            next
          end
          provider_instances[instance.name] = instance

          result = new(:name => instance.name, :provider => instance)
          properties.each { |name| result.newattr(name) }
          result
        end
      end.flatten.compact
    end

    # Lifecycle method for a resource. This is called during graph creation.
    # It should perform any consistency checking of the catalog and raise a
    # Puppet::Error if the transaction should be aborted.
    #
    # It differs from the validate method, since it is called later during
    # initialization and can rely on self.catalog to have references to all
    # resources that comprise the catalog.
    #
    # @see Puppet::Transaction#add_vertex
    # @raise [Puppet::Error] If the pre-run check failed.
    # @return [void]
    # @abstract a resource type may implement this method to perform
    #   validation checks that can query the complete catalog
    def pre_run_check
    end

    # Finishes any outstanding processing.
    # This method should be called as a final step in setup,
    # to allow the parameters that have associated auto-require needs to be processed.
    #
    # @todo what is the expected sequence here - who is responsible for calling this? When?
    #   Is the returned type correct?
    # @return [Array<Puppet::Parameter>] the validated list/set of attributes
    #
    def finish
      # Call post_compile hook on every parameter that implements it. This includes all subclasses
      # of parameter including, but not limited to, regular parameters, metaparameters, relationship
      # parameters, and properties.
      eachparameter do |parameter|
        parameter.post_compile if parameter.respond_to? :post_compile
      end

      # Make sure all of our relationships are valid.  Again, must be done
      # when the entire catalog is instantiated.
      self.class.relationship_params.collect do |klass|
        if param = @parameters[klass.name]
          param.validate_relationship
        end
      end.flatten.reject { |r| r.nil? }
    end

    # Returns true if all contained objects are in sync.
    # @todo "contained in what?" in the given "in" parameter?
    #
    # @todo deal with the comment _"FIXME I don't think this is used on the type instances any more,
    #   it's really only used for testing"_
    # @return [Boolean] true if in sync, false otherwise.
    #
    def insync?(is)
      insync = true

      if property = @parameters[:ensure]
        unless is.include? property
          raise Puppet::DevError,
                "The is value is not in the is array for '#{property.name}'"
        end
        ensureis = is[property]
        if property.safe_insync?(ensureis) and property.should == :absent
          return true
        end
      end

      properties.each { |prop|
        unless is.include? prop
          raise Puppet::DevError,
                "The is value is not in the is array for '#{prop.name}'"
        end

        propis = is[prop]
        unless prop.safe_insync?(propis)
          prop.debug("Not in sync: #{propis.inspect} vs #{prop.should.inspect}")
          insync = false
          #else
          #    property.debug("In sync")
        end
      }

      #self.debug("#{self} sync status is #{insync}")
      insync
    end

    # Says if the ensure property should be retrieved if the resource is ensurable
    # Defaults to true. Some resource type classes can override it
    def self.needs_ensure_retrieved
      true
    end

    # Retrieves the current value of all contained properties.
    # Parameters and meta-parameters are not included in the result.
    # @todo As opposed to all non contained properties? How is this different than any of the other
    #   methods that also "gets" properties/parameters/etc. ?
    # @return [Puppet::Resource] array of all property values (mix of types)
    # @raise [fail???] if there is a provider and it is not suitable for the host this is evaluated for.
    def retrieve
      fail "Provider #{provider.class.name} is not functional on this host" if self.provider.is_a?(Puppet::Provider) and ! provider.class.suitable?

      result = Puppet::Resource.new(self.class, title)

      # Provide the name, so we know we'll always refer to a real thing
      result[:name] = self[:name] unless self[:name] == title

      if ensure_prop = property(:ensure) or (self.class.needs_ensure_retrieved and self.class.validattr?(:ensure) and ensure_prop = newattr(:ensure))
        result[:ensure] = ensure_state = ensure_prop.retrieve
      else
        ensure_state = nil
      end

      properties.each do |property|
        next if property.name == :ensure
        if ensure_state == :absent
          result[property] = :absent
        else
          result[property] = property.retrieve
        end
      end

      result
    end

    # Returns a hash of the current properties and their values.
    # If a resource is absent, its value is the symbol `:absent`
    # @return [Hash{Puppet::Property => Object}] mapping of property instance to its value
    #
    def currentpropvalues
      # It's important to use the 'properties' method here, as it follows the order
      # in which they're defined in the class.  It also guarantees that 'ensure'
      # is the first property, which is important for skipping 'retrieve' on
      # all the properties if the resource is absent.
      ensure_state = false
      return properties.inject({}) do | prophash, property|
        if property.name == :ensure
          ensure_state = property.retrieve
          prophash[property] = ensure_state
        else
          if ensure_state == :absent
            prophash[property] = :absent
          else
            prophash[property] = property.retrieve
          end
        end
        prophash
      end
    end

    # Retrieve the current state of the system as a Puppet::Resource. For
    # the base Puppet::Type this does the same thing as #retrieve, but
    # specific types are free to implement #retrieve as returning a hash,
    # and this will call #retrieve and convert the hash to a resource.
    # This is used when determining when syncing a resource.
    #
    # @return [Puppet::Resource] A resource representing the current state
    #   of the system.
    #
    # @api private
    def retrieve_resource
      resource = retrieve
      resource = Resource.new(self.class, title, :parameters => resource) if resource.is_a? Hash
      resource
    end

    # Convert this resource type instance to a Puppet::Resource.
    # @return [Puppet::Resource] Returns a serializable representation of this resource
    #
    def to_resource
      resource = self.retrieve_resource
      resource.tag(*self.tags)

      @parameters.each do |name, param|
        # Avoid adding each instance name twice
        next if param.class.isnamevar? and param.value == self.title

        # We've already got property values
        next if param.is_a?(Puppet::Property)
        resource[name] = param.value
      end

      resource
    end

    # (see self_refresh)
    # @todo check that meaningful yardoc is produced - this method delegates to "self.class.self_refresh"
    # @return [Boolean] - ??? returns true when ... what?
    #
    def self_refresh?
      self.class.self_refresh
    end

    # Given the hash of current properties, should this resource be treated as if it
    # currently exists on the system. May need to be overridden by types that offer up
    # more than just :absent and :present.
    def present?(current_values)
      current_values[:ensure] != :absent
    end

    # @return [Boolean] Returns true if the wanted state of the resource is that it should be absent (i.e. to be deleted).
    def deleting?
      obj = @parameters[:ensure] and obj.should == :absent
    end

    # Marks the object as "being purged".
    # This method is used by transactions to forbid deletion when there are dependencies.
    # @todo what does this mean; "mark that we are purging" (purging what from where). How to use/when?
    #   Is this internal API in transactions?
    # @see purging?
    def purging
      @purging = true
    end

    # Returns whether this resource is being purged or not.
    # This method is used by transactions to forbid deletion when there are dependencies.
    # @return [Boolean] the current "purging" state
    #
    def purging?
      if defined?(@purging)
        @purging
      else
        false
      end
    end

  end
end
