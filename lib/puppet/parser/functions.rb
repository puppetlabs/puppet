require 'puppet/util/autoload'
require 'puppet/parser/scope'
require 'monitor'

# A module for managing parser functions.  Each specified function
# is added to a central module that then gets included into the Scope
# class.
module Puppet::Parser::Functions
  Environment = Puppet::Node::Environment

  class << self
    include Puppet::Util
  end

  # This is used by tests
  def self.reset
    @functions = Hash.new { |h,k| h[k] = {} }.extend(MonitorMixin)
    @modules = Hash.new.extend(MonitorMixin)

    # Runs a newfunction to create a function for each of the log levels
    Puppet::Util::Log.levels.each do |level|
      newfunction(level, :doc => "Log a message on the server at level #{level.to_s}.") do |vals|
        send(level, vals.join(" "))
      end
    end
  end

  def self.autoloader
    unless defined?(@autoloader)
      @autoloader = Puppet::Util::Autoload.new(
        self,
        "puppet/parser/functions",
        :wrap => false
      )
    end

    @autoloader
  end

  def self.environment_module(env = nil)
    @modules.synchronize {
      @modules[ env || Environment.current || Environment.root ] ||= Module.new
    }
  end

  # Create a new function type.
  def self.newfunction(name, options = {}, &block)
    name = name.intern

    raise Puppet::DevError, "Function #{name} already defined" if get_function(name)

    ftype = options[:type] || :statement

    unless ftype == :statement or ftype == :rvalue
      raise Puppet::DevError, "Invalid statement type #{ftype.inspect}"
    end

    fname = "function_#{name}"
    environment_module.send(:define_method, fname, &block)

    # Someday we'll support specifying an arity, but for now, nope
    #functions[name] = {:arity => arity, :type => ftype}
    func = {:type => ftype, :name => fname}
    func[:doc] = options[:doc] if options[:doc]

    add_function(name, func)
    func
  end

  # Remove a function added by newfunction
  def self.rmfunction(name)
    Puppet.deprecation_warning "Puppet::Parser::Functions.rmfunction is deprecated and will be removed in 3.0"
    name = name.intern

    raise Puppet::DevError, "Function #{name} is not defined" unless get_function(name)

    @functions.synchronize {
      @functions[Environment.current].delete(name)
      # This seems wrong because it won't delete a function defined on root if
      # the current environment is different
      #@functions[Environment.root].delete(name)
    }

    fname = "function_#{name}"
    # This also only deletes from the module associated with
    # Environment.current
    environment_module.send(:remove_method, fname)
  end

  # Determine if a given name is a function
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

  def self.functiondocs
    autoloader.loadall

    ret = ""

    merged_functions.sort { |a,b| a[0].to_s <=> b[0].to_s }.each do |name, hash|
      ret += "#{name}\n#{"-" * name.to_s.length}\n"
      if hash[:doc]
        ret += Puppet::Util::Docs.scrub(hash[:doc])
      else
        ret += "Undocumented.\n"
      end

      ret += "\n\n- *Type*: #{hash[:type]}\n\n"
    end

    ret
  end

  def self.functions(env = nil)
    Puppet.deprecation_warning "Puppet::Parser::Functions.functions is deprecated and will be removed in 3.0"
    @functions.synchronize {
      @functions[ env || Environment.current || Environment.root ]
    }
  end

  # Determine if a given function returns a value or not.
  def self.rvalue?(name)
    func = get_function(name)
    func ? func[:type] == :rvalue : false
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
