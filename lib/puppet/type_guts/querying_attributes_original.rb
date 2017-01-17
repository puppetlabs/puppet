# -*- coding: utf-8 -*-

# Types: all, metaparam, param, property
# Queries: list, class, ?, doc, each, by_name
# Results: [name*], Class, is X?, docstring, yield obj, obj

# special: attrtype maps for all to {:property,:param,:meta}

module Puppet
  class Type
    # ===== ALL =====

    # Returns all the attribute names of the type in the appropriate order.
    # The {key_attributes} come first, then the {provider}, then the {properties}, and finally
    # the {parameters} and {metaparams},
    # all in the order they were specified in the respective files.
    # @return [Array<String>] all type attribute names in a defined order.
    def self.allattrs
      key_attributes | (parameters & [:provider]) | properties.collect { |property| property.name } | parameters | metaparams
    end

    # Returns the class associated with the given attribute name.
    # @param name [String] the name of the attribute to obtain the class for
    # @return [Class, nil] the class for the given attribute, or nil if the name does not refer to an existing attribute
    def self.attrclass(name)
      @attrclasses ||= {}

      # We cache the value, since this method gets called such a huge number
      # of times (as in, hundreds of thousands in a given run).
      unless @attrclasses.include?(name)
        @attrclasses[name] = case self.attrtype(name)
                               when :property; @validproperties[name]
                               when :meta; @@metaparamhash[name]
                               when :param; @paramhash[name]
                             end
      end
      @attrclasses[name]
    end

    # Returns the attribute type (`:property`, `:param`, `:meta`).
    # @comment What type of parameter are we dealing with? Cache the results, because
    #   this method gets called so many times.
    # @return [Symbol] a symbol describing the type of attribute (`:property`, `;param`, `:meta`)
    def self.attrtype(attr)
      @attrtypes ||= {}
      unless @attrtypes.include?(attr)
        @attrtypes[attr] = case
                             when @validproperties.include?(attr); :property
                             when @paramhash.include?(attr); :param
                             when @@metaparamhash.include?(attr); :meta
                           end
      end

      @attrtypes[attr]
    end

    # missing: doc
    # missing: each

    # Returns whether or not the given name is the name of a property, parameter or meta-parameter
    # @return [Boolean] true if the given attribute name is the name of an existing property, parameter or meta-parameter
    #
    def self.validattr?(name)
      name = name.intern
      return true if name == :name
      @validattrs ||= {}

      unless @validattrs.include?(name)
        @validattrs[name] = !!(self.validproperty?(name) or self.validparameter?(name) or self.metaparam?(name))
      end

      @validattrs[name]
    end

    # (see validattr?)
    # @note see comment in code - how should this be documented? Are some of the other query methods deprecated?
    #   (or should be).
    # @comment This is a forward-compatibility method - it's the validity interface we'll use in Puppet::Resource.
    # @todo (DS) breaks naming conventions, as it returns information about ALL attributes
    def self.valid_parameter?(name)
      validattr?(name)
    end

    # missing: by_name

    # ===== METAPARAMS =====

    # Returns all meta-parameter names.
    # @return [Array<String>] all meta-parameter names
    def self.metaparams
      @@metaparams.collect { |param| param.name }
    end

    # Returns the meta-parameter class associated with the given meta-parameter name.
    # Accepts a `nil` name, and return nil.
    # @param name [String, nil] the name of a meta-parameter
    # @return [Class,nil] the class for the given meta-parameter, or `nil` if no such meta-parameter exists, (or if
    #   the given meta-parameter name is `nil`.
    def self.metaparamclass(name)
      return nil if name.nil?
      @@metaparamhash[name.intern]
    end

    # Is the given parameter a meta-parameter?
    # @return [Boolean] true if the given parameter is a meta-parameter.
    def self.metaparam?(param)
      @@metaparamhash.include?(param.intern)
    end

    # Returns the documentation for a given meta-parameter of this type.
    # @param metaparam [Puppet::Parameter] the meta-parameter to get documentation for.
    # @return [String] the documentation associated with the given meta-parameter, or nil of no such documentation
    #   exists.
    # @raise if the given metaparam is not a meta-parameter in this type
    def self.metaparamdoc(metaparam)
      @@metaparamhash[metaparam].doc
    end

    # Provides iteration over meta-parameters.
    # @yieldparam p [Puppet::Parameter] each meta parameter
    # @return [void]
    def self.eachmetaparam
      @@metaparams.each { |p| yield p.name }
    end

    # missing: by_name

    # ===== PARAMETERS =====

    # @return [Array<String>] Returns the parameter names
    def self.parameters
      return [] unless defined?(@parameters)
      @parameters.collect { |klass| klass.name }
    end

    # Returns a shallow copy of this object's hash of attributes by name.
    # Note that his not only comprises parameters, but also properties and metaparameters.
    # Changes to the contained parameters will have an effect on the parameters of this type, but changes to
    # the returned hash does not.
    # @return [Hash{String => Object}] a new hash being a shallow copy of the parameters map name to parameter
    # @todo (DS) this breaks the pattern and overlaps very ugly with self.parameters
    def parameters
      @parameters.dup
    end

    # @return [Puppet::Parameter] Returns the parameter class associated with the given parameter name.
    def self.paramclass(name)
      @paramhash[name]
    end

    # @return [Boolean] Returns true if the given name is the name of an existing parameter or meta-parameter
    # @todo (DS) this includes params AND meta-params, breaking the separation of the structure
    def self.validparameter?(name)
      raise Puppet::DevError, "Class #{self} has not defined parameters" unless defined?(@parameters)
      !!(@paramhash.include?(name) or @@metaparamhash.include?(name))
    end

    def self.paramdoc(param)
      @paramhash[param].doc
    end

    # Iterates over all parameters with value currently set.
    # @yieldparam parameter [Puppet::Parameter] or a subclass thereof
    # @return [void]
    def eachparameter
      parameters_with_value.each { |parameter| yield parameter }
    end

    # Returns the value of this object's parameter given by name
    # @param name [String] the name of the parameter
    # @return [Object] the value
    def parameter(name)
      @parameters[name.to_sym]
    end

    # ===== PROPERTIES =====

    # self.properties is a attr_reader

    # @return [Array<Puppet::Property>] Returns all of the property objects, in the order specified in the
    #   class.
    # @todo "what does the 'order specified in the class' mean? The order the properties where added in the
    #   ruby file adding a new type with new properties?
    # @todo (DS) this clashes in interesting ways with the Type class' attr_reader :properties.
    def properties
      self.class.properties.collect { |prop| @parameters[prop.name] }.compact
    end

    # @return [Array<Symbol>, {}] Returns a list of valid property names, or an empty hash if there are none.
    # @todo An empty hash is returned if there are no defined parameters (not an empty array). This looks like
    #   a bug.
    #
    def self.validproperties
      return {} unless defined?(@parameters)

      @validproperties.keys
    end

    # missing: class

    # @return [Boolean] Returns true if the given name is the name of an existing property
    def self.validproperty?(name)
      name = name.intern
      @validproperties.include?(name) && @validproperties[name]
    end

    # missing: doc

    # Iterates over the properties that were set on this resource.
    # @yieldparam property [Puppet::Property] each property
    # @return [void]
    def eachproperty
      # properties is a private method
      properties.each { |property|
        yield property
      }
    end

    # @return [Puppet::Property] Returns the property class ??? associated with the given property name
    def self.propertybyname(name)
      @validproperties[name]
    end

    # ===== OTHER QUERY METHODS =====

    # Return the parameters, metaparams, and properties that have a value or were set by a default. Properties are
    # included since they are a subclass of parameter.
    # @return [Array<Puppet::Parameter>] Array of parameter objects ( or subclass thereof )
    def parameters_with_value
      self.class.allattrs.collect { |attr| parameter(attr) }.compact
    end

    # @return [Boolean] Returns whether the attribute given by name has been added
    #   to this resource or not.
    # @todo (DS) method and action do not correspond. Remove
    def propertydefined?(name)
      name = name.intern unless name.is_a? Symbol
      @parameters.include?(name)
    end

    # Returns a {Puppet::Property} instance by name.
    # To return the value, use 'resource[param]'
    # @todo LAK:NOTE(20081028) Since the 'parameter' method is now a superset of this method,
    #   this one should probably go away at some point. - Does this mean it should be deprecated ?
    # @return [Puppet::Property] the property with the given name, or nil if not a property or does not exist.
    # @todo (DS) method and action do not correspond. Remove
    def property(name)
      (obj = @parameters[name.intern] and obj.is_a?(Puppet::Property)) ? obj : nil
    end

    # Returns all registered relationship(meta)params
    def self.relationship_params
      RelationshipMetaparam.subclasses
    end
  end
end
