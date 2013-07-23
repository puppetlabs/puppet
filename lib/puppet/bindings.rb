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
# For all details see {Puppet::Pops::Binder::BindingsFactory}, which is used behind the scenes.
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
    register(Puppet::Pops::Binder::BindingsFactory.named_bindings(name, &block).model)
  end

  # Registers a named_binding under its name
  # @param named_bindings [Puppet::Pops::Binder::Bindings::NamedBindings] The named bindings to register.
  # @api public
  #
  def self.register(named_bindings)
    adapter = NamedBindingsAdapter.adapt(Environment.current)
    adapter[named_bindings.name] = named_bindings
  end

  # Returns the named bindings with the given name, or nil if no such bindings have been registered.
  # @param name [String] The fully qualified name of a binding to get
  # @api public
  #
  def self.get(name)
    adapter = NamedBindingsAdapter.adapt(Environment.current)
    adapter[name]
  end

  def self.[](name)
    get(name)
  end

  # Supports Enumerable iteration (k,v) over the named bindings hash.
  def self.each
    adapter = NamedBindingsAdapter.adapt(Environment.current)
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
      unless value.is_a?(Puppet::Pops::Binder::Bindings::NamedBindings)
        raise ArgumentError, "Given value must be a NamedBindings, got: #{value.class}."
      end
      @named_bindings[name] = value
    end

    def each_pair(&block)
      @named_bindings.each_pair(&block)
    end
  end

end