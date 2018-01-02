require_relative 'interpolation'

module Puppet::Pops
module Lookup
# The EnvironmentContext is adapted to the current environment
#
class EnvironmentContext < Adaptable::Adapter
  class FileData
    attr_reader :data

    def initialize(path, inode, mtime, size, data)
      @path = path
      @inode = inode
      @mtime = mtime
      @size = size
      @data = data
    end

    def valid?(stat)
      stat.ino == @inode && stat.mtime == @mtime && stat.size == @size
    end
  end

  attr_reader :environment_name

  def self.create_adapter(environment)
    new(environment)
  end

  def initialize(environment)
    @environment_name = environment.name
    @file_data_cache = {}
  end

  # Loads the contents of the file given by _path_. The content is then yielded to the provided block in
  # case a block is given, and the returned value from that block is cached and returned by this method.
  # If no block is given, the content is stored instead.
  #
  # The cache is retained as long as the inode, mtime, and size of the file remains unchanged.
  #
  # @param path [String] path to the file to be read
  # @yieldparam content [String] the content that was read from the file
  # @yieldreturn [Object] some result based on the content
  # @return [Object] the content, or if a block was given, the return value of the block
  #
  def cached_file_data(path)
    file_data = @file_data_cache[path]
    stat = Puppet::FileSystem.stat(path)
    unless file_data && file_data.valid?(stat)
      Puppet.debug("File at '#{path}' was changed, reloading") if file_data
      content = Puppet::FileSystem.read(path, :encoding => 'utf-8')
      file_data = FileData.new(path, stat.ino, stat.mtime, stat.size, block_given? ? yield(content) : content)
      @file_data_cache[path] = file_data
    end
    file_data.data
  end
end

# A FunctionContext is created for each unique hierarchy entry and adapted to the Compiler (and hence shares
# the compiler's life-cycle).
# @api private
class FunctionContext
  include Interpolation

  attr_reader :module_name, :function
  attr_accessor :data_hash

  def initialize(environment_context, module_name, function)
    @data_hash = nil
    @cache = {}
    @environment_context = environment_context
    @module_name = module_name
    @function = function
  end

  def cache(key, value)
    @cache[key] = value
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

  def cached_file_data(path, &block)
    @environment_context.cached_file_data(path, &block)
  end

  def environment_name
    @environment_context.environment_name
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

  def self._pcore_type
    @type
  end

  def self.register_ptype(loader, ir)
    tf = Types::TypeFactory
    key_type = tf.optional(tf.scalar)
    @type = Pcore::create_object_type(loader, ir, self, 'Puppet::LookupContext', 'Any',
      {
        'environment_name' => {
          Types::KEY_TYPE => Types::PStringType::NON_EMPTY,
          Types::KEY_KIND => Types::PObjectType::ATTRIBUTE_KIND_DERIVED
        },
        'module_name' => {
          Types::KEY_TYPE => tf.variant(Types::PStringType::NON_EMPTY, Types::PUndefType::DEFAULT)
        }
      },
      {
        'not_found' => tf.callable([0, 0], tf.undef),
        'explain' => tf.callable([0, 0, tf.callable(0,0)], tf.undef),
        'interpolate' => tf.callable(1, 1),
        'cache' => tf.callable([key_type, tf.any], tf.any),
        'cache_all' => tf.callable([tf.hash_kv(key_type, tf.any)], tf.undef),
        'cache_has_key' => tf.callable([key_type], tf.boolean),
        'cached_value' => tf.callable([key_type], tf.any),
        'cached_entries' => tf.variant(
          tf.callable([0, 0, tf.callable(1,1)], tf.undef),
          tf.callable([0, 0, tf.callable(2,2)], tf.undef),
          tf.callable([0, 0], tf.iterable(tf.tuple([key_type, tf.any])))),
        'cached_file_data' => tf.callable(tf.string, tf.optional(tf.callable([1, 1])))
      }
    ).resolve(loader)
  end

  # Mainly for test purposes. Makes it possible to create a {Context} in Puppet code provided that a current {Invocation} exists.
  def self.from_asserted_args(module_name)
    new(FunctionContext.new(EnvironmentContext.adapt(Puppet.lookup(:environments).get(Puppet[:environment])), module_name, nil), Invocation.current)
  end

  # Public methods delegated to the {FunctionContext}
  def_delegators :@function_context, :cache, :cache_all, :cache_has_key, :cached_value, :cached_entries, :environment_name, :module_name, :cached_file_data

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
