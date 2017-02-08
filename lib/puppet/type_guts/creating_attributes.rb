# -*- coding: utf-8 -*-

# Code related to creating resource type attributes.

module Puppet
  # @comment Types (which map to resources in the languages) are entirely composed of
  #   attribute value pairs.  Generally, Puppet calls any of these things an
  #   'attribute', but these attributes always take one of three specific
  #   forms:  parameters, metaparams, or properties.

  # @comment In naming methods, I have tried to consistently name the method so
  #   that it is clear whether it operates on all attributes (thus has 'attr' in
  #   the method name, or whether it operates on a specific type of attributes.
  class Type
    class << self
      include Puppet::Util::ClassGen
      include Puppet::Util::Warnings

      # @return [Array<Puppet::Property>] The list of declared properties for the resource type.
      # The returned lists contains instances if Puppet::Property or its subclasses.
      attr_reader :properties
    end

    # Processes the options for a named parameter.
    # @param name [String] the name of a parameter
    # @param options [Hash] a hash of options
    # @option options [Boolean] :boolean if option set to true, an access method on the form _name_? is added for the param
    # @return [void]
    # @todo (DS) could be private, only used in new(meta)param.
    # @todo (DS) the only thing this method does is creating a utility method for boolean attributes. Questionable.
    def self.handle_param_options(name, options)
      # If it's a boolean parameter, create a method to test the value easily
      if options[:boolean]
        define_method(name.to_s + "?") do
          val = self[name]
          if val == :true or val == true
            return true
          end
        end
      end
    end

    # Creates a new meta-parameter.
    # This creates a new meta-parameter that is added to this and all inheriting types.
    # @param name [Symbol] the name of the parameter
    # @param options [Hash] a hash with options.
    # @option options [Class<inherits Puppet::Parameter>] :parent (Puppet::Parameter) the super class of this parameter
    # @option options [Hash{String => Object}] :attributes a hash that is applied to the generated class
    #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
    #   block is evaluated.
    # @option options [Boolean] :boolean (false) specifies if this is a boolean parameter
    # @option options [Boolean] :namevar  (false) specifies if this parameter is the namevar
    # @option options [Symbol, Array<Symbol>] :required_features  specifies required provider features by name
    # @return [Class<inherits Puppet::Parameter>] the created parameter
    # @yield [ ] a required block that is evaluated in the scope of the new meta-parameter
    # @api public
    # @dsl type
    # @todo Verify that this description is ok
    def self.newmetaparam(name, options = {}, &block)
      @@metaparams ||= []
      @@metaparamhash ||= {}
      name = name.intern

      param = genclass(
          name,
          :parent => options[:parent] || Puppet::Parameter,
          :prefix => "MetaParam",
          :hash => @@metaparamhash,
          :array => @@metaparams,
          :attributes => options[:attributes],
          &block
      )

      # Grr.
      param.required_features = options[:required_features] if options[:required_features]

      handle_param_options(name, options)

      param.metaparam = true

      param
    end

    # Creates a new parameter.
    # @param name [Symbol] the name of the parameter
    # @param options [Hash] a hash with options.
    # @option options [Class<inherits Puppet::Parameter>] :parent (Puppet::Parameter) the super class of this parameter
    # @option options [Hash{String => Object}] :attributes a hash that is applied to the generated class
    #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
    #   block is evaluated.
    # @option options [Boolean] :boolean (false) specifies if this is a boolean parameter
    # @option options [Boolean] :namevar  (false) specifies if this parameter is the namevar
    # @option options [Symbol, Array<Symbol>] :required_features  specifies required provider features by name
    # @return [Class<inherits Puppet::Parameter>] the created parameter
    # @yield [ ] a required block that is evaluated in the scope of the new parameter
    # @api public
    # @dsl type
    #
    def self.newparam(name, options = {}, &block)
      options[:attributes] ||= {}

      param = genclass(
          name,
          :parent     => options[:parent] || Puppet::Parameter,
          :attributes => options[:attributes],
          :block      => block,
          :prefix     => "Parameter",
          :array      => @parameters,
          :hash       => @paramhash
      )

      handle_param_options(name, options)

      # Grr.
      param.required_features = options[:required_features] if options[:required_features]

      param.isnamevar if options[:namevar]

      param
    end

    # Creates a new property.
    # @param name [Symbol] the name of the property
    # @param options [Hash] a hash with options.
    # @option options [Symbol] :array_matching (:first) specifies how the current state is matched against
    #   the wanted state. Use `:first` if the property is single valued, and (`:all`) otherwise.
    # @option options [Class<inherits Puppet::Property>] :parent (Puppet::Property) the super class of this property
    # @option options [Hash{String => Object}] :attributes a hash that is applied to the generated class
    #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
    #   block is evaluated.
    # @option options [Boolean] :boolean (false) specifies if this is a boolean parameter
    # @option options [Symbol] :retrieve the method to call on the provider (or `parent` if `provider` is not set)
    #   to retrieve the current value of this property.
    # @option options [Symbol, Array<Symbol>] :required_features  specifies required provider features by name
    # @return [Class<inherits Puppet::Property>] the created property
    # @yield [ ] a required block that is evaluated in the scope of the new property
    # @api public
    # @dsl type
    #
    def self.newproperty(name, options = {}, &block)
      name = name.intern

      # This is here for types that might still have the old method of defining
      # a parent class.
      unless options.is_a? Hash
        raise Puppet::DevError,
              "Options must be a hash, not #{options.inspect}"
      end

      raise Puppet::DevError, "Class #{self.name} already has a property named #{name}" if @validproperties.include?(name)

      if parent = options[:parent]
        options.delete(:parent)
      else
        parent = Puppet::Property
      end

      # We have to create our own, new block here because we want to define
      # an initial :retrieve method, if told to, and then eval the passed
      # block if available.
      prop = genclass(name, :parent => parent, :hash => @validproperties, :attributes => options) do
        # If they've passed a retrieve method, then override the retrieve
        # method on the class.
        if options[:retrieve]
          define_method(:retrieve) do
            provider.send(options[:retrieve])
          end
        end

        class_eval(&block) if block
      end

      # If it's the 'ensure' property, always put it first.
      if name == :ensure
        @properties.unshift prop
      else
        @properties << prop
      end

      prop
    end

    # Registers an attribute to this resource type instance.
    # Requires either the attribute name or class as its argument.
    # This is a noop if the named property/parameter is not supported
    # by this resource. Otherwise, an attribute instance is created
    # and kept in this resource's parameters hash.
    # @overload newattr(name)
    #   @param name [Symbol] symbolic name of the attribute
    # @overload newattr(klass)
    #   @param klass [Class] a class supported as an attribute class, i.e. a subclass of
    #     Parameter or Property
    # @return [Object] An instance of the named Parameter or Property class associated
    #   to this resource type instance, or nil if the attribute is not supported
    #
    def newattr(name)
      if name.is_a?(Class)
        klass = name
        name = klass.name
      end

      unless klass = self.class.attrclass(name)
        raise Puppet::Error, "Resource type #{self.class.name} does not support parameter #{name}"
      end

      if provider and ! provider.class.supports_parameter?(klass)
        missing = klass.required_features.find_all { |f| ! provider.class.feature?(f) }
        debug "Provider %s does not support features %s; not managing attribute %s" % [provider.class.name, missing.join(", "), name]
        return nil
      end

      return @parameters[name] if @parameters.include?(name)

      @parameters[name] = klass.new(:resource => self)
    end

    # Creates a new `ensure` property with configured default values or with configuration by an optional block.
    # This method is a convenience method for creating a property `ensure` with default accepted values.
    # If no block is specified, the new `ensure` property will accept the default symbolic
    # values `:present`, and `:absent` - see {Puppet::Property::Ensure}.
    # If something else is wanted, pass a block and make calls to {Puppet::Property.newvalue} from this block
    # to define each possible value. If a block is passed, the defaults are not automatically added to the set of
    # valid values.
    #
    # @note This method will be automatically called without a block if the type implements the methods
    #   specified by {ensurable?}. It is recommended to always call this method and not rely on this automatic
    #   specification to clearly state that the type is ensurable.
    #
    # @overload ensurable()
    # @overload ensurable({|| ... })
    # @yield [ ] A block evaluated in scope of the new Parameter
    # @yieldreturn [void]
    # @return [void]
    # @dsl type
    # @api public
    #
    def self.ensurable(&block)
      if block_given?
        self.newproperty(:ensure, :parent => Puppet::Property::Ensure, &block)
      else
        self.newproperty(:ensure, :parent => Puppet::Property::Ensure) do
          self.defaultvalues
        end
      end
    end

    # Returns true if the type implements the default behavior expected by being _ensurable_ "by default".
    # A type is _ensurable_ by default if it responds to `:exists`, `:create`, and `:destroy`.
    # If a type implements these methods and have not already specified that it is _ensurable_, it will be
    # made so with the defaults specified in {ensurable}.
    # @return [Boolean] whether the type is _ensurable_ or not.
    #
    def self.ensurable?
      # If the class has all three of these methods defined, then it's
      # ensurable.
      [:exists?, :create, :destroy].all? { |method|
        self.public_method_defined?(method)
      }
    end

    # Creates a new property value holder for the resource if it is valid and does not already exist
    # @return [Boolean] true if a new parameter was added, false otherwise
    # @todo (DS) this is unused within the puppet repo
    def add_property_parameter(prop_name)
      if self.class.validproperty?(prop_name) && !@parameters[prop_name]
        self.newattr(prop_name)
        return true
      end
      false
    end

    # Removes an attribute from the object; useful in testing or in cleanup
    # when an error has been encountered
    # @todo Don't know what the attr is (name or Property/Parameter?). Guessing it is a String name...
    # @todo Is it possible to delete a meta-parameter?
    # @todo What does delete mean? Is it deleted from the type or is its value state 'is'/'should' deleted?
    # @param attr [String] the attribute to delete from this object. WHAT IS THE TYPE?
    # @raise [Puppet::DecError] when an attempt is made to delete an attribute that does not exists.
    #
    def delete(attr)
      attr = attr.intern
      if @parameters.has_key?(attr)
        @parameters.delete(attr)
      else
        raise Puppet::DevError.new("Undefined attribute '#{attr}' in #{self}")
      end
    end
  end
end
