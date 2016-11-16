require_relative 'interpolation'

module Puppet::Pops
module Lookup
# A FunctionContext is created for each unique hierarchy entry and adapted to the Compiler (and hence shares
# the compiler's life-cycle).
# @api private
class FunctionContext
  include Interpolation

  attr_reader :environment_name, :module_name, :function
  attr_accessor :data_hash

  def initialize(environment_name, module_name, function)
    @data_hash = nil
    @cache = {}
    @environment_name = environment_name
    @module_name = module_name
    @function = function
  end

  def cache(key, value)
    @cache[key] = value
    nil
  end

  def cache_all(hash)
    @cache.merge!(hash)
    nil
  end

  def cache_has_key(key)
    @cache.include?(key)
  end

  def cached_value(key)
    @cache[key]
  end

  def cached_entries(&block)
    if block_given?
      enumerator = @cache.each_pair
      @cache.size.times do
        if block.arity == 2
          yield(*enumerator.next)
        else
          yield(enumerator.next)
        end
      end
      nil
    else
      Types::Iterable.on(@cache)
    end
  end
end

# The Context is created once for each call to a function. It provides a combination of the {Invocation} object needed
# to provide explanation support and the {FunctionContext} object needed to provide the private cache.
# The {Context} is part of the public API. It will be passed to a _data_hash_, _data_dig_, or _lookup_key_ function and its
# attributes and methods can be used in a Puppet function as well as in a Ruby function.
# The {Context} is maps to the Pcore type 'Puppet::LookupContext'
#
# @api public
class Context
  include Types::PuppetObject
  extend Forwardable

  def self._ptype
    @type
  end

  def self.register_ptype(loader, ir)
    tf = Types::TypeFactory
    @type = Pcore::create_object_type(loader, ir, self, 'Puppet::LookupContext', 'Any',
      {
        'environment_name' => Types::PStringType::NON_EMPTY,
        'module_name' => {
          Types::KEY_TYPE => tf.optional(Types::PStringType::NON_EMPTY),
          Types::KEY_VALUE => nil
        }
      },
      {
        'not_found' => tf.callable([0, 0], tf.undef),
        'explain' => tf.callable([0, 0, tf.callable(0,0)], tf.undef),
        'interpolate' => tf.callable(1, 1),
        'cache' => tf.callable([tf.scalar, tf.any], tf.undef),
        'cache_all' => tf.callable([tf.hash_kv(tf.scalar, tf.any)], tf.undef),
        'cache_has_key' => tf.callable([tf.scalar], tf.boolean),
        'cached_value' => tf.callable([tf.scalar], tf.any),
        'cached_entries' => tf.variant(
          tf.callable([0, 0, tf.callable(1,1)], tf.undef),
          tf.callable([0, 0, tf.callable(2,2)], tf.undef),
          tf.callable([0, 0], tf.iterable(tf.tuple([tf.scalar, tf.any])))
        )
      }
    ).resolve(Types::TypeParser.singleton, loader)
  end

  # Mainly for test purposes. Makes it possible to create a {Context} in Puppet code provided that a current {Invocation} exists.
  def self.from_asserted_args(environment_name, module_name)
    new(FunctionContext.new(environment_name, module_name, nil), Invocation.current)
  end

  # Public methods delegated to the {FunctionContext}
  def_delegators :@function_context, :cache, :cache_all, :cache_has_key, :cached_value, :cached_entries, :environment_name, :module_name

  def initialize(function_context, lookup_invocation)
    @lookup_invocation = lookup_invocation
    @function_context = function_context
  end

  # Will call the given block to obtain a textual explanation if explanation support is active.
  #
  def explain(&block)
    @lookup_invocation.report_text(&block)
    nil
  end

  # Resolve interpolation expressions in the given value
  # @param [Object] value
  # @return [Object] the value with all interpolation expressions resolved
  def interpolate(value)
    @function_context.interpolate(value, @lookup_invocation, true)
  end

  def not_found
    throw :no_such_key
  end

  # @api private
  def invocation
    @lookup_invocation
  end
end
end
end
