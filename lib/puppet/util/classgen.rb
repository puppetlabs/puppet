require 'puppet/util/methodhelper'

module Puppet
  class ConstantAlreadyDefined < Error; end
  class SubclassAlreadyDefined < Error; end
end

# This is a utility module for generating classes.
# @api public
#
module Puppet::Util::ClassGen
  include Puppet::Util::MethodHelper
  include Puppet::Util

  # Create a new class.
  # @param name [String] the name of the generated class
  # @param options [Hash] a hash of options
  # @option options [Array<Class>] :array if specified, the generated class is appended to this array
  # @option options [Hash<{String => Object}>] :attributes a hash that is applied to the generated class
  #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
  #   block is evaluated.
  # @option options [Proc] :block a block to evaluate in the context of the class (this block can be provided
  #   this way, or as a normal yield block).
  # @option options [String] :constant (name with first letter capitalized) what to set the constant that references
  #   the generated class to.
  # @option options [Hash] :hash a hash of existing classes that this class is appended to (name => class).
  #   This hash must be specified if the `:overwrite` option is set to `true`.
  # @option options [Boolean] :overwrite whether an overwrite of an existing class should be allowed (requires also
  #   defining the `:hash` with existing classes as the test is based on the content of this hash).
  # @option options [Class] :parent (self) the parent class of the generated class.
  # @option options [String] ('') :prefix the constant prefix to prepend to the constant name referencing the
  #   generated class.
  # @return [Class] the generated class
  #
  def genclass(name, options = {}, &block)
    genthing(name, Class, options, block)
  end

  # Creates a new module.
  # @param name [String] the name of the generated module
  # @param options [Hash] hash with options
  # @option options [Array<Class>] :array if specified, the generated class is appended to this array
  # @option options [Hash<{String => Object}>] :attributes a hash that is applied to the generated class
  #   by calling setter methods corresponding to this hash's keys/value pairs. This is done before the given
  #   block is evaluated.
  # @option options [Proc] :block a block to evaluate in the context of the class (this block can be provided
  #   this way, or as a normal yield block).
  # @option options [String] :constant (name with first letter capitalized) what to set the constant that references
  #   the generated class to.
  # @option options [Hash] :hash a hash of existing classes that this class is appended to (name => class).
  #   This hash must be specified if the `:overwrite` option is set to `true`.
  # @option options [Boolean] :overwrite whether an overwrite of an existing class should be allowed (requires also
  #   defining the `:hash` with existing classes as the test is based on the content of this hash).
  #   the capitalized name is appended and the result is set as the constant.
  # @option options [String] ('') :prefix the constant prefix to prepend to the constant name referencing the
  #   generated class.
  # @return [Module] the generated Module
  def genmodule(name, options = {}, &block)
    genthing(name, Module, options, block)
  end

  # Removes an existing class.
  # @param name [String] the name of the class to remove
  # @param options [Hash] options
  # @option options [Hash] :hash a hash of existing classes from which the class to be removed is also removed
  # @return [Boolean] whether the class was removed or not
  #
  def rmclass(name, options)
    options = symbolize_options(options)
    const = genconst_string(name, options)
    retval = false
    if is_constant_defined?(const)
      remove_const(const)
      retval = true
    end

    if hash = options[:hash] and hash.include? name
      hash.delete(name)
      retval = true
    end

    # Let them know whether we did actually delete a subclass.
    retval
  end

  private

  # Generates the constant to create or remove.
  # @api private
  def genconst_string(name, options)
    unless const = options[:constant]
      prefix = options[:prefix] || ""
      const = prefix + name2const(name)
    end

    const
  end

  # This does the actual work of creating our class or module.  It's just a
  # slightly abstract version of genclass.
  # @api private
  def genthing(name, type, options, block)
    options = symbolize_options(options)

    name = name.to_s.downcase.intern

    if type == Module
      #evalmethod = :module_eval
      evalmethod = :class_eval
      # Create the class, with the correct name.
      klass = Module.new do
        class << self
          attr_reader :name
        end
        @name = name
      end
    else
      options[:parent] ||= self
      evalmethod = :class_eval
      # Create the class, with the correct name.
      klass = Class.new(options[:parent]) do
        @name = name
      end
    end

    # Create the constant as appropriation.
    handleclassconst(klass, name, options)

    # Initialize any necessary variables.
    initclass(klass, options)

    block ||= options[:block]

    # Evaluate the passed block if there is one.  This should usually
    # define all of the work.
    klass.send(evalmethod, &block) if block

    klass.postinit if klass.respond_to? :postinit

    # Store the class in hashes or arrays or whatever.
    storeclass(klass, name, options)

    klass
  end

  # @api private
  #
  def is_constant_defined?(const)
    const_defined?(const, false)
  end

  # Handle the setting and/or removing of the associated constant.
  # @api private
  #
  def handleclassconst(klass, name, options)
   const = genconst_string(name, options)

    if is_constant_defined?(const)
      if options[:overwrite]
        Puppet.info _("Redefining %{name} in %{klass}") % { name: name, klass: self }
        remove_const(const)
      else
        raise Puppet::ConstantAlreadyDefined,
          _("Class %{const} is already defined in %{klass}") % { const: const, klass: self }
      end
    end
    const_set(const, klass)

    const
  end

  # Perform the initializations on the class.
  # @api private
  #
  def initclass(klass, options)
    klass.initvars if klass.respond_to? :initvars

    if attrs = options[:attributes]
      attrs.each do |param, value|
        method = param.to_s + "="
        klass.send(method, value) if klass.respond_to? method
      end
    end

    [:include, :extend].each do |method|
      if set = options[method]
        set = [set] unless set.is_a?(Array)
        set.each do |mod|
          klass.send(method, mod)
        end
      end
    end

    klass.preinit if klass.respond_to? :preinit
  end

  # Convert our name to a constant.
  # @api private
  def name2const(name)
    name.to_s.capitalize
  end

  # Store the class in the appropriate places.
  # @api private
  def storeclass(klass, klassname, options)
    if hash = options[:hash]
      if hash.include? klassname and ! options[:overwrite]
        raise Puppet::SubclassAlreadyDefined,
          _("Already a generated class named %{klassname}") % { klassname: klassname }
      end

      hash[klassname] = klass
    end

    # If we were told to stick it in a hash, then do so
    if array = options[:array]
      if (klass.respond_to? :name and
              array.find { |c| c.name == klassname } and
              ! options[:overwrite])
        raise Puppet::SubclassAlreadyDefined,
          _("Already a generated class named %{klassname}") % { klassname: klassname }
      end

      array << klass
    end
  end
end

