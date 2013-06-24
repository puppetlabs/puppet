require 'puppet/util/autoload'
require 'puppet/parser/scope'
require 'monitor'

# A module for managing bindings.
#
# @api public
module Puppet::Bindings
  Environment = Puppet::Node::Environment

  class << self
    include Puppet::Util
  end

  # Reset the list of loaded functions.
  #
  # @api private
  def self.reset
    @functions = Hash.new { |h,k| h[k] = {} }.extend(MonitorMixin)
    @modules = Hash.new.extend(MonitorMixin)

    # can initialize default (static bindings) here
  end

  # Accessor for singleton autoloader
  #
  # @api private
  def self.autoloader
    @autoloader ||= Puppet::Util::Autoload.new(
      self, "puppet/bindings", :wrap => false
    )
  end

  # Get the module that bindings are mixed into corresponding to an
  # environment
  #
  # @api private
  def self.environment_module(env = nil)
    if env and ! env.is_a?(Puppet::Node::Environment)
      env = Puppet::Node::Environment.new(env)
    end
    @modules.synchronize {
      @modules[ (env || Environment.current || Environment.root).name ] ||= create_environment_module()
    }
  end

  # Creates the environment module and eagerly outoload all bindings
  #
  def self.create_environment_module()
    # This loadall will load all bindings from the gem-path as well as all modules.
    # The expected behavior is that they call back to the Binder module methods
    # to define the respective binding model.
    # When all have been processed, there should be a set of bindings in the module
    # DUH - that does not work since it is not possible to populate the module - it is not bound yet
    autoloader.loadall()
  end

  def self.bind(klazz, name, producer)
  end
  def self.multibind(klazz, name, identity)
  end

  def self.newfunction(name, options = {}, &block)
    name = name.intern

    Puppet.warning "Overwriting previous definition for function #{name}" if get_function(name)

    arity = options[:arity] || -1
    ftype = options[:type] || :statement

    unless ftype == :statement or ftype == :rvalue
      raise Puppet::DevError, "Invalid statement type #{ftype.inspect}"
    end

    # the block must be installed as a method because it may use "return",
    # which is not allowed from procs.
    real_fname = "real_function_#{name}"
    environment_module.send(:define_method, real_fname, &block)

    fname = "function_#{name}"
    environment_module.send(:define_method, fname) do |*args|
      Puppet::Util::Profiler.profile("Called #{name}") do
        if args[0].is_a? Array
          if arity >= 0 and args[0].size != arity
            raise ArgumentError, "#{name}(): Wrong number of arguments given (#{args[0].size} for #{arity})"
          elsif arity < 0 and args[0].size < (arity+1).abs
            raise ArgumentError, "#{name}(): Wrong number of arguments given (#{args[0].size} for minimum #{(arity+1).abs})"
          end
          self.send(real_fname, args[0])
        else
          raise ArgumentError, "custom functions must be called with a single array that contains the arguments. For example, function_example([1]) instead of function_example(1)"
        end
      end
    end

    func = {:arity => arity, :type => ftype, :name => fname}
    func[:doc] = options[:doc] if options[:doc]

    add_function(name, func)
    func
  end

  # Determine if a function is defined
  #
  # @param [Symbol] name the function
  #
  # @return [Symbol, false] The name of the function if it's defined,
  #   otherwise false.
  #
  # @api public
  def self.function(name)
    name = name.intern

    func = nil
    @functions.synchronize do
      unless func = get_function(name)
        autoloader.load(name, Environment.current)
        func = get_function(name)
      end
    end

    if func
      func[:name]
    else
      false
    end
  end


  class << self
    private

    def merged_functions
      @functions.synchronize {
        @functions[Environment.root].merge(@functions[Environment.current])
      }
    end

    def get_function(name)
      name = name.intern
      merged_functions[name]
    end

    def add_function(name, func)
      name = name.intern
      @functions.synchronize {
        @functions[Environment.current][name] = func
      }
    end
  end

  reset  # initialize the class instance variables
end
