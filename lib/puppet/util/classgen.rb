module Puppet
  class ConstantAlreadyDefined < Error; end
  class SubclassAlreadyDefined < Error; end
end

module Puppet::Util::ClassGen
  include Puppet::Util::MethodHelper
  include Puppet::Util

  # Create a new subclass.  Valid options are:
  # * <tt>:array</tt>: An array of existing classes.  If specified, the new
  #   class is added to this array.
  # * <tt>:attributes</tt>: A hash of attributes to set before the block is
  #   evaluated.
  # * <tt>:block</tt>: The block to evaluate in the context of the class.
  #   You can also just pass the block normally, but it will still be evaluated
  #   with <tt>class_eval</tt>.
  # * <tt>:constant</tt>: What to set the constant as.  Defaults to the
  #   capitalized name.
  # * <tt>:hash</tt>: A hash of existing classes.  If specified, the new
  #   class is added to this hash, and it is also used for overwrite tests.
  # * <tt>:overwrite</tt>: Whether to overwrite an existing class.
  # * <tt>:parent</tt>: The parent class for the generated class.  Defaults to
  #   self.
  # * <tt>:prefix</tt>: The constant prefix.  Default to nothing; if specified,
  #   the capitalized name is appended and the result is set as the constant.
  def genclass(name, options = {}, &block)
    genthing(name, Class, options, block)
  end

  # Create a new module.  Valid options are:
  # * <tt>:array</tt>: An array of existing classes.  If specified, the new
  #   class is added to this array.
  # * <tt>:attributes</tt>: A hash of attributes to set before the block is
  #   evaluated.
  # * <tt>:block</tt>: The block to evaluate in the context of the class.
  #   You can also just pass the block normally, but it will still be evaluated
  #   with <tt>class_eval</tt>.
  # * <tt>:constant</tt>: What to set the constant as.  Defaults to the
  #   capitalized name.
  # * <tt>:hash</tt>: A hash of existing classes.  If specified, the new
  #   class is added to this hash, and it is also used for overwrite tests.
  # * <tt>:overwrite</tt>: Whether to overwrite an existing class.
  # * <tt>:prefix</tt>: The constant prefix.  Default to nothing; if specified,
  #   the capitalized name is appended and the result is set as the constant.
  def genmodule(name, options = {}, &block)
    genthing(name, Module, options, block)
  end

  # Remove an existing class
  def rmclass(name, options)
    options = symbolize_options(options)
    const = genconst_string(name, options)
    retval = false
    if const_defined?(const)
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

  # Generate the constant to create or remove.
  def genconst_string(name, options)
    unless const = options[:constant]
      prefix = options[:prefix] || ""
      const = prefix + name2const(name)
    end

    const
  end

  # This does the actual work of creating our class or module.  It's just a
  # slightly abstract version of genclass.
  def genthing(name, type, options, block)
    options = symbolize_options(options)

    name = symbolize(name.to_s.downcase)

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

  # const_defined? in Ruby 1.9 behaves differently in terms
  # of which class hierarchy it polls for nested namespaces
  #
  # See http://redmine.ruby-lang.org/issues/show/1915
  def is_constant_defined?(const)
    if ::RUBY_VERSION =~ /1.9/
      const_defined?(const, false)
    else
      const_defined?(const)
    end
  end

  # Handle the setting and/or removing of the associated constant.
  def handleclassconst(klass, name, options)
    const = genconst_string(name, options)

    if is_constant_defined?(const)
      if options[:overwrite]
        Puppet.info "Redefining #{name} in #{self}"
        remove_const(const)
      else
        raise Puppet::ConstantAlreadyDefined,
          "Class #{const} is already defined in #{self}"
      end
    end
    const_set(const, klass)

    const
  end

  # Perform the initializations on the class.
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
  def name2const(name)
    name.to_s.capitalize
  end

  # Store the class in the appropriate places.
  def storeclass(klass, klassname, options)
    if hash = options[:hash]
      if hash.include? klassname and ! options[:overwrite]
        raise Puppet::SubclassAlreadyDefined,
          "Already a generated class named #{klassname}"
      end

      hash[klassname] = klass
    end

    # If we were told to stick it in a hash, then do so
    if array = options[:array]
      if (klass.respond_to? :name and
              array.find { |c| c.name == klassname } and
              ! options[:overwrite])
        raise Puppet::SubclassAlreadyDefined,
          "Already a generated class named #{klassname}"
      end

      array << klass
    end
  end
end

