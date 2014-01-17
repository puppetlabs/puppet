# This class allows registration of named bindings that are later contributed to a layer via
# a binding scheme.
#
# The intended use is for a .rb file to be placed in confdir's or module's `lib/bindings` directory structure, with a
# name corresponding to the symbolic bindings name.
#
# Here are two equivalent examples, the first using chained methods (which is compact for simple cases), and the
# second which uses a block.
#
# @example MyModule's lib/bindings/mymodule/default.rb
#   Puppet::Bindings.newbindings('mymodule::default') do
#     bind.integer.named('meaning of life').to(42)
#   end
#
# @example Using blocks
#   Puppet::Bindings.newbindings('mymodule::default') do
#     bind do
#       integer
#       name 'meaning of life'
#       to 42
#     end
#   end
#
# If access is needed to the scope, this can be declared as a block parameter.
# @example MyModule's lib/bindings/mymodule/default.rb with scope
#   Puppet::Bindings.newbindings('mymodule::default') do |scope|
#     bind.integer.named('meaning of life').to("#{scope['::fqdn']} also think it is 42")
#   end
#
# If late evaluation is wanted, this can be achieved by binding a puppet expression.
# @example binding a puppet expression
#   Puppet::Bindings.newbindings('mymodule::default') do |scope|
#     bind.integer.named('meaning of life').to(puppet_string("${::fqdn} also think it is 42")
#   end
#
# It is allowed to define methods in the block given to `newbindings`, these can be used when
# producing bindings. (Care should naturally be taken to not override any of the already defined methods).
# @example defining method to be used while creating bindings
#   Puppet::Bindings.newbindings('mymodule::default') do
#     def square(x)
#       x * x
#     end
#     bind.integer.named('meaning of life squared').to(square(42))
#   end
#
# For all details see {Puppet::Pops::Binder::BindingsFactory}, which is used behind the scenes.
# @api public
#
class Puppet::Bindings
  extend Enumerable

  Environment = Puppet::Node::Environment

  # Constructs and registers a {Puppet::Pops::Binder::Bindings::NamedBindings NamedBindings} that later can be contributed
  # to a bindings layer in a bindings configuration via a URI. The name is symbolic, fully qualified with module name, and at least one
  # more qualifying name (where the name `default` is used in the default bindings configuration.
  #
  # The given block is called with a `self` bound to an instance of {Puppet::Pops::Binder::BindingsFactory::BindingsContainerBuilder}
  # which most notably has a `#bind` method which it turn calls a block bound to an instance of
  # {Puppet::Pops::Binder::BindingsFactory::BindingsBuilder}.
  # Depending on the use-case a direct chaining method calls or nested blocks may be used.
  #
  # @example simple bindings
  #   Puppet::Bindings.newbindings('mymodule::default') do
  #     bind.name('meaning of life').to(42)
  #     bind.integer.named('port').to(8080)
  #     bind.integer.named('apache::port').to(8080)
  #   end
  #
  # The block form is more suitable for longer, more complex forms of bindings.
  #
  def self.newbindings(name, &block)
    register_proc(name, block)
  end

  def self.register_proc(name, block)
    adapter = NamedBindingsAdapter.adapt(Puppet.lookup(:current_environment))
    adapter[name] = block
  end

  # Registers a named_binding under its name
  # @param named_bindings [Puppet::Pops::Binder::Bindings::NamedBindings] The named bindings to register.
  # @api public
  #
  def self.register(named_bindings)
    adapter = NamedBindingsAdapter.adapt(Puppet.lookup(:current_environment))
    adapter[named_bindings.name] = named_bindings
  end

  def self.resolve(scope, name)
    entry = get(name)
    return entry unless entry.is_a?(Proc)
    named_bindings = Puppet::Pops::Binder::BindingsFactory.safe_named_bindings(name, scope, &entry).model
    adapter = NamedBindingsAdapter.adapt(Puppet.lookup(:current_environment))
    adapter[named_bindings.name] = named_bindings
    named_bindings
  end

  # Returns the named bindings with the given name, or nil if no such bindings have been registered.
  # @param name [String] The fully qualified name of a binding to get
  # @return [Proc, Puppet::Pops::Binder::Bindings::NamedBindings] a Proc producing named bindings, or a named bindings directly
  # @api public
  #
  def self.get(name)
    adapter = NamedBindingsAdapter.adapt(Puppet.lookup(:current_environment))
    adapter[name]
  end

  def self.[](name)
    get(name)
  end

  # Supports Enumerable iteration (k,v) over the named bindings hash.
  def self.each
    adapter = NamedBindingsAdapter.adapt(Puppet.lookup(:current_environment))
    adapter.each_pair {|k,v| yield k,v }
  end

  # A NamedBindingsAdapter holds a map of name to Puppet::Pops::Binder::Bindings::NamedBindings.
  # It is intended to be used as an association between an Environment and named bindings.
  #
  class NamedBindingsAdapter < Puppet::Pops::Adaptable::Adapter
    def initialize()
      @named_bindings = {}
    end

    def [](name)
      @named_bindings[name]
    end

    def has_name?(name)
      @named_bindings.has_key?
    end

    def []=(name, value)
      unless value.is_a?(Puppet::Pops::Binder::Bindings::NamedBindings) || value.is_a?(Proc)
        raise ArgumentError, "Given value must be a NamedBindings, or a Proc producing one, got: #{value.class}."
      end
      @named_bindings[name] = value
    end

    def each_pair(&block)
      @named_bindings.each_pair(&block)
    end
  end

end
