require 'puppet'
require 'puppet/util/classgen'
require 'puppet/node/environment'

# This module defines methods dealing with Type management.
# This module gets included into the Puppet::Type class, it's just split out here for clarity.
# @api public
#
module Puppet::MetaType
module Manager
  include Puppet::Util::ClassGen

  # An implementation specific method that removes all type instances during testing.
  # @note Only use this method for testing purposes.
  # @api private
  #
  def allclear
    @types.each { |name, type|
      type.clear
    }
  end

  # Clears any types that were used but absent when types were last loaded.
  # @note Used after each catalog compile when always_retry_plugins is false
  # @api private
  #
  def clear_misses
    unless @types.nil?
      @types.delete_if {|_, v| v.nil? }
    end
  end

  # Iterates over all already loaded Type subclasses.
  # @yield [t] a block receiving each type
  # @yieldparam t [Puppet::Type] each defined type
  # @yieldreturn [Object] the last returned object is also returned from this method
  # @return [Object] the last returned value from the block.
  def eachtype
    @types.each do |name, type|
      # Only consider types that have names
      #if ! type.parameters.empty? or ! type.validproperties.empty?
        yield type
      #end
    end
  end

  # Loads all types.
  # @note Should only be used for purposes such as generating documentation as this is potentially a very
  #  expensive operation.
  # @return [void]
  #
  def loadall
    typeloader.loadall
  end

  # Defines a new type or redefines an existing type with the given name.
  # A convenience method on the form `new<name>` where name is the name of the type is also created.
  # (If this generated method happens to clash with an existing method, a warning is issued and the original
  # method is kept).
  #
  # @param name [String] the name of the type to create or redefine.
  # @param options [Hash] options passed on to {Puppet::Util::ClassGen#genclass} as the option `:attributes`.
  # @option options [Puppet::Type]
  #   Puppet::Type. This option is not passed on as an attribute to genclass.
  # @yield [ ] a block evaluated in the context of the created class, thus allowing further detailing of
  #   that class.
  # @return [Class<inherits Puppet::Type>] the created subclass
  # @see Puppet::Util::ClassGen.genclass
  #
  # @dsl type
  # @api public
  def newtype(name, options = {}, &block)
    # Handle backward compatibility
    unless options.is_a?(Hash)
      Puppet.warning "Puppet::Type.newtype(#{name}) now expects a hash as the second argument, not #{options.inspect}"
    end

    # First make sure we don't have a method sitting around
    name = name.intern
    newmethod = "new#{name}"

    # Used for method manipulation.
    selfobj = singleton_class

    @types ||= {}

    if @types.include?(name)
      if self.respond_to?(newmethod)
        # Remove the old newmethod
        selfobj.send(:remove_method,newmethod)
      end
    end

    options = symbolize_options(options)

    # Then create the class.

    klass = genclass(
      name,
      :parent => Puppet::Type,
      :overwrite => true,
      :hash => @types,
      :attributes => options,
      &block
    )

    # Now define a "new<type>" method for convenience.
    if self.respond_to? newmethod
      # Refuse to overwrite existing methods like 'newparam' or 'newtype'.
      Puppet.warning "'new#{name.to_s}' method already exists; skipping"
    else
      selfobj.send(:define_method, newmethod) do |*args|
        klass.new(*args)
      end
    end

    # If they've got all the necessary methods defined and they haven't
    # already added the property, then do so now.
    klass.ensurable if klass.ensurable? and ! klass.validproperty?(:ensure)

    # Now set up autoload any providers that might exist for this type.

    klass.providerloader = Puppet::Util::Autoload.new(klass, "puppet/provider/#{klass.name.to_s}")

    # We have to load everything so that we can figure out the default provider.
    klass.providerloader.loadall Puppet.lookup(:current_environment)
    klass.providify unless klass.providers.empty?

    loc = block_given? ? block.source_location : nil
    uri = loc.nil? ? nil : URI("#{Puppet::Util.path_to_uri(loc[0])}?line=#{loc[1]}")
    Puppet::Pops::Loaders.register_runtime3_type(name, uri)

    klass
  end

  # Removes an existing type.
  # @note Only use this for testing.
  # @api private
  def rmtype(name)
    # Then create the class.

    rmclass(name, :hash => @types)

    singleton_class.send(:remove_method, "new#{name}") if respond_to?("new#{name}")
  end

  # Returns a Type instance by name.
  # This will load the type if not already defined.
  # @param [String, Symbol] name of the wanted Type
  # @return [Puppet::Type, nil] the type or nil if the type was not defined and could not be loaded
  #
  def type(name)
    # Avoid loading if name obviously is not a type name
    if name.to_s.include?(':')
      return nil
    end

    @types ||= {}

    # We are overwhelmingly symbols here, which usually match, so it is worth
    # having this special-case to return quickly.  Like, 25K symbols vs. 300
    # strings in this method. --daniel 2012-07-17
    return @types[name] if @types.include? name

    # Try mangling the name, if it is a string.
    if name.is_a? String
      name = name.downcase.intern
      return @types[name] if @types.include? name
    end
    # Try loading the type.
    if typeloader.load(name, Puppet.lookup(:current_environment))
      Puppet.warning "Loaded puppet/type/#{name} but no class was created" unless @types.include? name
    elsif !Puppet[:always_retry_plugins]
      # PUP-5482 - Only look for a type once if plugin retry is disabled
      @types[name] = nil
    end

    # ...and I guess that is that, eh.
    return @types[name]
  end

  # Creates a loader for Puppet types.
  # Defaults to an instance of {Puppet::Util::Autoload} if no other auto loader has been set.
  # @return [Puppet::Util::Autoload] the loader to use.
  # @api private
  def typeloader
    unless defined?(@typeloader)
      @typeloader = Puppet::Util::Autoload.new(self, "puppet/type")
    end

    @typeloader
  end
end
end

