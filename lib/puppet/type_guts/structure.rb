# -*- coding: utf-8 -*-

module Puppet
  class Type
    class << self
      # @return [String] the name of the resource type; e.g., "File"
      #
      attr_reader :name

      # @return [Boolean] true if the type should send itself a refresh event on change.
      #
      attr_accessor :self_refresh
      include Enumerable
      include Puppet::Util
      include Puppet::Util::Logging
    end

    include Enumerable

    extend Puppet::CompilableResourceType

    include Puppet::Util
    include Puppet::Util::Errors
    include Puppet::Util::Logging
    include Puppet::Util::Tagging

    # The title attribute of WHAT ???
    # @todo Figure out what this is the title attribute of (it appears on line 1926 currently).
    # @return [String] the title
    attr_writer :title

    # The noop attribute of WHAT ??? does WHAT???
    # @todo Figure out what this is the noop attribute of (it appears on line 1931 currently).
    # @return [???] the noop WHAT ??? (mode? if so of what, or noop for an instance of the type, or for all
    #   instances of a type, or for what???
    #
    attr_writer :noop

    # @return [String] The file from which this type originates from
    attr_accessor :file

    # @return [Integer] The line in {#file} from which this type originates from
    attr_accessor :line

    # @todo what does this mean "this resource" (sounds like this if for an instance of the type, not the meta Type),
    #   but not sure if this is about the catalog where the meta Type is included)
    # @return [??? TODO] The catalog that this resource is stored in.
    attr_accessor :catalog

    # @return [Boolean] Flag indicating if this type is exported
    attr_accessor :exported

    # @return [Boolean] Returns whether the resource is exported or not
    def exported?; !!@exported; end

    # @return [Boolean] Flag indicating if the type is virtual (it should not be).
    attr_accessor :virtual

    # @return [Boolean] Returns whether the resource is virtual or not
    def virtual?;  !!@virtual;  end

    # @return [Hash] hash of parameters originally defined
    # @api private
    attr_reader :original_parameters

    # @comment For now, leave the 'name' method functioning like it used to.  Once 'title'
    #   works everywhere, I'll switch it.
    # Returns the resource's name
    # @todo There is a comment in source that this is not quite the same as ':title' and that a switch should
    #   be made...
    # @return [String] the name of a resource
    def name
      self[:name]
    end

    # Returns the title of this object, or its name if title was not explicitly set.
    # If the title is not already set, it will be computed by looking up the {#name_var} and using
    # that value as the title.
    # @todo it is somewhat confusing that if the name_var is a valid parameter, it is assumed to
    #  be the name_var called :name, but if it is a property, it uses the name_var.
    #  It is further confusing as Type in some respects supports multiple namevars.
    #
    # @return [String] Returns the title of this object, or its name if title was not explicitly set.
    # @raise [??? devfail] if title is not set, and name_var can not be found.
    def title
      unless @title
        if self.class.validparameter?(name_var)
          @title = self[:name]
        elsif self.class.validproperty?(name_var)
          @title = self.should(name_var)
        else
          self.devfail "Could not find namevar #{name_var} for #{self.class.name}"
        end
      end

      @title
    end

    # Returns the parent of this in the catalog.  In case of an erroneous catalog
    # where multiple parents have been produced, the first found (non
    # deterministic) parent is returned.
    # @return [Puppet::Type, nil] the
    #   containing resource or nil if there is no catalog or no containing
    #   resource.
    def parent
      return nil unless catalog

      @parent ||=
          if parents = catalog.adjacent(self, :direction => :in)
            parents.shift
          else
            nil
          end
    end

    # Converts a simple hash into a Resource instance.
    # @todo as opposed to a complex hash? Other raised exceptions?
    # @param [Hash{Symbol, String => Object}] hash resource attribute to value map to initialize the created resource from
    # @return [Puppet::Resource] the resource created from the hash
    # @raise [Puppet::Error] if a title is missing in the given hash
    def self.hash2resource(hash)
      hash = hash.inject({}) { |result, ary| result[ary[0].to_sym] = ary[1]; result }

      title = hash.delete(:title)
      title ||= hash[:name]
      title ||= hash[key_attributes.first] if key_attributes.length == 1

      raise Puppet::Error, "Title or name must be provided" unless title

      # Now create our resource.
      resource = Puppet::Resource.new(self, title)
      resource.catalog = hash.delete(:catalog)

      hash.each do |param, value|
        resource[param] = value
      end
      resource
    end

    # Creates an instance of Type from a hash or a {Puppet::Resource}.
    # @todo Unclear if this is a new Type or a new instance of a given type (the initialization ends
    #   with calling validate - which seems like validation of an instance of a given type, not a new
    #   meta type.
    #
    # @todo Explain what the Hash and Resource are. There seems to be two different types of
    #   resources; one that causes the title to be set to resource.title, and one that
    #   causes the title to be resource.ref ("for components") - what is a component?
    #
    # @overload initialize(hash)
    #   @param [Hash] hash
    #   @raise [Puppet::ResourceError] when the type validation raises
    #     Puppet::Error or ArgumentError
    # @overload initialize(resource)
    #   @param resource [Puppet:Resource]
    #   @raise [Puppet::ResourceError] when the type validation raises
    #     Puppet::Error or ArgumentError
    #
    def initialize(resource)
      resource = self.class.hash2resource(resource) unless resource.is_a?(Puppet::Resource)

      # The list of parameter/property instances.
      @parameters = {}

      # Set the title first, so any failures print correctly.
      if resource.type.to_s.downcase.to_sym == self.class.name
        self.title = resource.title
      else
        # This should only ever happen for components
        self.title = resource.ref
      end

      [:file, :line, :catalog, :exported, :virtual].each do |getter|
        setter = getter.to_s + "="
        if val = resource.send(getter)
          self.send(setter, val)
        end
      end

      @tags = resource.tags

      @original_parameters = resource.to_hash

      set_name(@original_parameters)

      set_default(:provider)

      set_parameters(@original_parameters)

      begin
        self.validate if self.respond_to?(:validate)
      rescue Puppet::Error, ArgumentError => detail
        error = Puppet::ResourceError.new("Validation of #{ref} failed: #{detail}")
        adderrorcontext(error, detail)
        raise error
      end

      set_sensitive_parameters(resource.sensitive_parameters)
    end

    # Initializes all of the variables that must be initialized for each subclass.
    # @todo Does the explanation make sense?
    # @todo (DS) this seems to be only called in spec tests and providers, in the latter to enable `command` to work.
    # @return [void]
    def self.initvars
      # all of the instances of this class
      @objects = Hash.new
      @aliases = Hash.new

      @defaults = {}

      @parameters ||= []

      @validproperties = {}
      @properties = []
      @parameters = []
      @paramhash = {}

      @paramdoc = Hash.new { |hash,key|
        key = key.intern if key.is_a?(String)
        if hash.include?(key)
          hash[key]
        else
          "Param Documentation for #{key} not found"
        end
      }

      @doc ||= ""

    end

    # Forcibly remove all internal references to held memory. This allows the GC to collect the memory, and makes this
    # object unusable.
    def remove()
      # This is hackish (mmm, cut and paste), but it works for now, and it's
      # better than warnings.
      @parameters.each do |name, obj|
        obj.remove
      end
      @parameters.clear

      @parent = nil

      # Remove the reference to the provider.
      if self.provider
        @provider.clear
        @provider = nil
      end
    end

    # @todo the comment says: "Convert our object to a hash.  This just includes properties."
    # @todo this is confused, again it is the @parameters instance variable that is consulted, and
    #   each value is copied - does it contain "properties" and "parameters" or both? Does it contain
    #   meta-parameters?
    #
    # @return [Hash{ ??? => ??? }] a hash of WHAT?. The hash is a shallow copy, any changes to the
    #  objects returned in this hash will be reflected in the original resource having these attributes.
    #
    def to_hash
      rethash = {}

      @parameters.each do |name, obj|
        rethash[name] = obj.value
      end

      rethash
    end

    # Sets the initial list of tags to associate to this resource.
    #
    # @return [void] ???
    def tags=(list)
      tag(self.class.name)
      tag(*list)
    end

    protected

    # Mark parameters associated with this type as sensitive, based on the associated resource.
    #
    # Currently, only instances of `Puppet::Property` can be easily marked for sensitive data handling
    # and information redaction is limited to redacting events generated while synchronizing
    # properties. While support for redaction will be broadened in the future we can't automatically
    # deduce how to redact arbitrary parameters, so if a parameter is marked for redaction the best
    # we can do is warn that we can't handle treating that parameter as sensitive and move on.
    #
    # In some unusual cases a given parameter will be marked as sensitive but that sensitive context
    # needs to be transferred to another parameter. In this case resource types may need to override
    # this method in order to copy the sensitive context from one parameter to another (and in the
    # process force the early generation of a parameter that might otherwise be lazily generated.)
    # See `Puppet::Type.type(:file)#set_sensitive_parameters` for an example of this.
    #
    # @note This method visibility is protected since it should only be called by #initialize, but is
    #   marked as public as subclasses may need to override this method.
    #
    # @api public
    #
    # @param sensitive_parameters [Array<Symbol>] A list of parameters to mark as sensitive.
    #
    # @return [void]
    def set_sensitive_parameters(sensitive_parameters)
      sensitive_parameters.each do |name|
        p = parameter(name)
        if p.is_a?(Puppet::Property)
          p.sensitive = true
        elsif p.is_a?(Puppet::Parameter)
          warning("Unable to mark '#{name}' as sensitive: #{name} is a parameter and not a property, and cannot be automatically redacted.")
        elsif self.class.attrclass(name)
          warning("Unable to mark '#{name}' as sensitive: the property itself was not assigned a value.")
        else
          err("Unable to mark '#{name}' as sensitive: the property itself is not defined on #{type}.")
        end
      end
    end

    private

    # Sets the name of the resource from a hash containing a mapping of `name_var` to value.
    # Sets the value of the property/parameter appointed by the `name_var` (if it is defined). The value set is
    # given by the corresponding entry in the given hash - e.g. if name_var appoints the name `:path` the value
    # of `:path` is set to the value at the key `:path` in the given hash. As a side effect this key/value is then
    # removed from the given hash.
    #
    # @note This method mutates the given hash by removing the entry with a key equal to the value
    #   returned from name_var!
    # @param hash [Hash] a hash of what
    # @return [void]
    def set_name(hash)
      self[name_var] = hash.delete(name_var) if name_var
    end

    # Sets parameters from the given hash.
    # Values are set in _attribute order_ i.e. higher priority attributes before others, otherwise in
    # the order they were specified (as opposed to just setting them in the order they happen to appear in
    # when iterating over the given hash).
    #
    # Attributes that are not included in the given hash are set to their default value.
    #
    # @todo Is this description accurate? Is "ensure" an example of such a higher priority attribute?
    # @return [void]
    # @raise [Puppet::DevError] when impossible to set the value due to some problem
    # @raise [ArgumentError, TypeError, Puppet::Error] when faulty arguments have been passed
    #
    def set_parameters(hash)
      # Use the order provided by allattrs, but add in any
      # extra attributes from the resource so we get failures
      # on invalid attributes.
      no_values = []
      (self.class.allattrs + hash.keys).uniq.each do |attr|
        begin
          # Set any defaults immediately.  This is mostly done so
          # that the default provider is available for any other
          # property validation.
          if hash.has_key?(attr)
            self[attr] = hash[attr]
          else
            no_values << attr
          end
        rescue ArgumentError, Puppet::Error, TypeError
          raise
        rescue => detail
          error = Puppet::DevError.new( "Could not set #{attr} on #{self.class.name}: #{detail}")
          error.set_backtrace(detail.backtrace)
          raise error
        end
      end
      no_values.each do |attr|
        set_default(attr)
      end
    end
  end
end
