require 'deep_merge/core'

module Puppet::Pops
  # Merges to objects into one based on an implemented strategy.
  #
  class MergeStrategy
    NOT_FOUND = Object.new.freeze

    def self.strategies
      @@strategies ||= {}
    end
    private_class_method :strategies

    # Finds the merge strategy for the given _merge_, creates an instance of it and returns that instance.
    #
    # @param merge [MergeStrategy,String,Hash<String,Object>,nil] The merge strategy. Can be a string or symbol denoting the key
    #   identifier or a hash with options where the key 'strategy' denotes the key
    # @return [MergeStrategy] The matching merge strategy
    #
    def self.strategy(merge)
      return DefaultMergeStrategy::INSTANCE unless merge
      return merge if merge.is_a?(MergeStrategy)

      if merge.is_a?(Hash)
        merge_strategy = merge['strategy']
        if merge_strategy.nil?
          #TRANSLATORS 'merge' is a variable name and 'strategy' is a key and should not be translated
          raise ArgumentError, _("The hash given as 'merge' must contain the name of a strategy in string form for the key 'strategy'")
        end
        merge_options  = merge.size == 1 ? EMPTY_HASH : merge
      else
        merge_strategy = merge
        merge_options = EMPTY_HASH
      end
      merge_strategy = merge_strategy.to_sym if merge_strategy.is_a?(String)
      strategy_class = strategies[merge_strategy]
      raise ArgumentError, _("Unknown merge strategy: '%{strategy}'") % { strategy: merge_strategy } if strategy_class.nil?
      merge_options == EMPTY_HASH ? strategy_class::INSTANCE : strategy_class.new(merge_options)
    end

    # Returns the list of merge strategy keys known to this class
    #
    # @return [Array<Symbol>] List of strategy keys
    #
    def self.strategy_keys
      strategies.keys - [:default, :unconstrained_deep, :reverse_deep]
    end

    # Adds a new merge strategy to the map of strategies known to this class
    #
    # @param strategy_class [Class<MergeStrategy>] The class of the added strategy
    #
    def self.add_strategy(strategy_class)
      unless MergeStrategy > strategy_class
        #TRANSLATORS 'MergeStrategies.add_strategy' is a method, 'stratgey_class' is a variable and 'MergeStrategy' is a class name and should not be translated
        raise ArgumentError, _("MergeStrategies.add_strategy 'strategy_class' must be a 'MergeStrategy' class. Got %{strategy_class}") %
            { strategy_class: strategy_class }
      end
      strategies[strategy_class.key] = strategy_class
      nil
    end

    # Finds a merge strategy that corresponds to the given _merge_ argument and delegates the task of merging the elements of _e1_ and _e2_ to it.
    #
    # @param e1 [Object] The first element
    # @param e2 [Object] The second element
    # @return [Object] The result of the merge
    #
    def self.merge(e1, e2, merge)
      strategy(merge).merge(e1, e2)
    end

    def self.key
      raise NotImplementedError, "Subclass must implement 'key'"
    end

    # Create a new instance of this strategy configured with the given _options_
    # @param merge_options [Hash<String,Object>] Merge options
    def initialize(options)
      assert_type('The merge options', self.class.options_t, options) unless options.empty?
      @options = options
    end

    # Merges the elements of _e1_ and _e2_ according to the rules of this strategy and options given when this
    # instance was created
    #
    # @param e1 [Object] The first element
    # @param e2 [Object] The second element
    # @return [Object] The result of the merge
    #
    def merge(e1, e2)
      checked_merge(
        assert_type('The first element of the merge', value_t, e1),
        assert_type('The second element of the merge', value_t, e2))
    end

    # TODO: API 5.0 Remove this method
    # @deprecated
    def merge_lookup(lookup_variants)
      lookup(lookup_variants, Lookup::Invocation.current)
    end

    # Merges the result of yielding the given _lookup_variants_ to a given block.
    #
    # @param lookup_variants [Array] The variants to pass as second argument to the given block
    # @return [Object] the merged value.
    # @yield [} ]
    # @yieldparam variant [Object] each variant given in the _lookup_variants_ array.
    # @yieldreturn [Object] the value to merge with other values
    # @throws :no_such_key if the lookup was unsuccessful
    #
    # Merges the result of yielding the given _lookup_variants_ to a given block.
    #
    # @param lookup_variants [Array] The variants to pass as second argument to the given block
    # @return [Object] the merged value.
    # @yield [} ]
    # @yieldparam variant [Object] each variant given in the _lookup_variants_ array.
    # @yieldreturn [Object] the value to merge with other values
    # @throws :no_such_key if the lookup was unsuccessful
    #
    def lookup(lookup_variants, lookup_invocation)
      case lookup_variants.size
      when 0
        throw :no_such_key
      when 1
        merge_single(yield(lookup_variants[0]))
      else
        lookup_invocation.with(:merge, self) do
          result = lookup_variants.reduce(NOT_FOUND) do |memo, lookup_variant|
            not_found = true
            value = catch(:no_such_key) do
              v = yield(lookup_variant)
              not_found = false
              v
            end
            if not_found
              memo
            else
              memo.equal?(NOT_FOUND) ? convert_value(value) : merge(memo, value)
            end
          end
          throw :no_such_key if result == NOT_FOUND
          lookup_invocation.report_result(result)
        end
      end
    end

    # Converts a single value to the type expected when merging two elements
    # @param value [Object] the value to convert
    # @return [Object] the converted value
    def convert_value(value)
      value
    end

    # Applies the merge strategy on a single element. Only applicable for `unique`
    # @param value [Object] the value to merge with nothing
    # @return [Object] the merged value
    def merge_single(value)
      value
    end

    def options
      @options
    end

    def configuration
      if @options.nil? || @options.empty?
        self.class.key.to_s
      else
        @options.include?('strategy') ? @options : { 'strategy' => self.class.key.to_s }.merge(@options)
      end
    end

    protected

    # Returns the type used to validate the options hash
    #
    # @return [Types::PStructType] the puppet type
    #
    def self.options_t
      @options_t ||=Types::TypeParser.singleton.parse("Struct[{strategy=>Optional[Pattern[/#{key}/]]}]")
    end

    # Returns the type used to validate the options hash
    #
    # @return [Types::PAnyType] the puppet type
    #
    def value_t
      raise NotImplementedError, "Subclass must implement 'value_t'"
    end

    def checked_merge(e1, e2)
      raise NotImplementedError, "Subclass must implement 'checked_merge(e1,e2)'"
    end

    def assert_type(param, type, value)
      Types::TypeAsserter.assert_instance_of(param, type, value)
    end
  end

  # Simple strategy that returns the first value found. It never merges any values.
  #
  class FirstFoundStrategy < MergeStrategy
    INSTANCE = self.new(EMPTY_HASH)

    def self.key
      :first
    end

    # Returns the first value found
    #
    # @param lookup_variants [Array] The variants to pass as second argument to the given block
    # @return [Object] the merged value
    # @throws :no_such_key unless the lookup was successful
    #
    def lookup(lookup_variants, _)
      # First found does not continue when a root key was found and a subkey wasn't since that would
      # simulate a hash merge
      lookup_variants.each { |lookup_variant| catch(:no_such_key) { return yield(lookup_variant) } }
      throw :no_such_key
    end

    protected

    def value_t
      @value_t ||= Types::PAnyType::DEFAULT
    end

    MergeStrategy.add_strategy(self)
  end

  # Same as {FirstFoundStrategy} but used when no strategy has been explicitly given
  class DefaultMergeStrategy < FirstFoundStrategy
    INSTANCE = self.new(EMPTY_HASH)

    def self.key
      :default
    end

    MergeStrategy.add_strategy(self)
  end

  # Produces a new hash by merging hash e1 with hash e2 in such a way that the values of duplicate keys
  # will be those of e1
  #
  class HashMergeStrategy < MergeStrategy
    INSTANCE = self.new(EMPTY_HASH)

    def self.key
      :hash
    end

    # @param e1 [Hash<String,Object>] The hash that will act as the source of the merge
    # @param e2 [Hash<String,Object>] The hash that will act as the receiver for the merge
    # @return [Hash<String,Object]] The merged hash
    # @see Hash#merge
    def checked_merge(e1, e2)
      e2.merge(e1)
    end

    protected

    def value_t
      @value_t ||= Types::TypeParser.singleton.parse('Hash[String,Data]')
    end

    MergeStrategy.add_strategy(self)
  end

  # Merges two values that must be either scalar or arrays into a unique set of values.
  #
  # Scalar values will be converted into a one element arrays and array values will be flattened
  # prior to forming the unique set. The order of the elements is preserved with e1 being the
  # first contributor of elements and e2 the second.
  #
  class UniqueMergeStrategy < MergeStrategy
    INSTANCE = self.new(EMPTY_HASH)

    def self.key
      :unique
    end

    # @param e1 [Array<Object>] The first array
    # @param e2 [Array<Object>] The second array
    # @return [Array<Object>] The unique set of elements
    #
    def checked_merge(e1, e2)
      convert_value(e1) | convert_value(e2)
    end

    def convert_value(e)
      e.is_a?(Array) ? e.flatten : [e]
    end

    # If _value_ is an array, then return the result of calling `uniq` on that array. Otherwise,
    # the argument is returned.
    # @param value [Object] the value to merge with nothing
    # @return [Object] the merged value
    def merge_single(value)
      value.is_a?(Array) ? value.uniq : value
    end

    protected

    def value_t
      @value_t ||= Types::TypeParser.singleton.parse('Variant[Scalar,Array[Data]]')
    end

    MergeStrategy.add_strategy(self)
  end

  # Documentation copied from https://github.com/danielsdeleo/deep_merge/blob/master/lib/deep_merge/core.rb
  # altered with respect to _preserve_unmergeables_ since this implementation always disables that option.
  #
  # The destination is dup'ed before the deep_merge is called to allow frozen objects as values.
  #
  # deep_merge method permits merging of arbitrary child elements. The two top level
  # elements must be hashes. These hashes can contain unlimited (to stack limit) levels
  # of child elements. These child elements to not have to be of the same types.
  # Where child elements are of the same type, deep_merge will attempt to merge them together.
  # Where child elements are not of the same type, deep_merge will skip or optionally overwrite
  # the destination element with the contents of the source element at that level.
  # So if you have two hashes like this:
  #   source = {:x => [1,2,3], :y => 2}
  #   dest =   {:x => [4,5,'6'], :y => [7,8,9]}
  #   dest.deep_merge!(source)
  #   Results: {:x => [1,2,3,4,5,'6'], :y => 2}
  #
  # "deep_merge" will unconditionally overwrite any unmergeables and merge everything else.
  #
  # Options:
  #   Options are specified in the last parameter passed, which should be in hash format:
  #   hash.deep_merge!({:x => [1,2]}, {:knockout_prefix => '--'})
  #   - 'knockout_prefix' Set to string value to signify prefix which deletes elements from existing element. Defaults is _undef_
  #   - 'sort_merged_arrays' Set to _true_ to sort all arrays that are merged together. Default is _false_
  #   - 'merge_hash_arrays' Set to _true_ to merge hashes within arrays. Default is _false_
  #
  # Selected Options Details:
  # :knockout_prefix => The purpose of this is to provide a way to remove elements
  #   from existing Hash by specifying them in a special way in incoming hash
  #    source = {:x => ['--1', '2']}
  #    dest   = {:x => ['1', '3']}
  #    dest.ko_deep_merge!(source)
  #    Results: {:x => ['2','3']}
  #   Additionally, if the knockout_prefix is passed alone as a string, it will cause
  #   the entire element to be removed:
  #    source = {:x => '--'}
  #    dest   = {:x => [1,2,3]}
  #    dest.ko_deep_merge!(source)
  #    Results: {:x => ""}
  #
  # :merge_hash_arrays => merge hashes within arrays
  #   source = {:x => [{:y => 1}]}
  #   dest   = {:x => [{:z => 2}]}
  #   dest.deep_merge!(source, {:merge_hash_arrays => true})
  #   Results: {:x => [{:y => 1, :z => 2}]}
  #
  class DeepMergeStrategy < MergeStrategy
    INSTANCE = self.new(EMPTY_HASH)

    def self.key
      :deep
    end

    def checked_merge(e1, e2)
      dm_options = { :preserve_unmergeables => false }
      options.each_pair { |k,v| dm_options[k.to_sym] = v unless k == 'strategy' }
      # e2 (the destination) is deep cloned to avoid that the passed in object mutates
      DeepMerge.deep_merge!(e1, deep_clone(e2), dm_options)
    end

    def deep_clone(value)
      if value.is_a?(Hash)
        result = value.clone
        value.each{ |k, v| result[k] = deep_clone(v) }
        result
      elsif value.is_a?(Array)
        value.map{ |v| deep_clone(v) }
      else
        value
      end
    end

    protected

    # Returns a type that allows all deep_merge options except 'preserve_unmergeables' since we force
    # the setting of that option to false
    #
    # @return [Types::PAnyType] the puppet type used when validating the options hash
    def self.options_t
      @options_t ||= Types::TypeParser.singleton.parse('Struct[{'\
          "strategy=>Optional[Pattern[#{key}]],"\
          'knockout_prefix=>Optional[String],'\
          'merge_debug=>Optional[Boolean],'\
          'merge_hash_arrays=>Optional[Boolean],'\
          'sort_merged_arrays=>Optional[Boolean],'\
          '}]')
    end

    def value_t
      @value_t ||= Types::PAnyType::DEFAULT
    end

    MergeStrategy.add_strategy(self)
  end

  # Same as {DeepMergeStrategy} but without constraint on valid merge options
  # (needed for backward compatibility with Hiera v3)
  class UnconstrainedDeepMergeStrategy < DeepMergeStrategy
    def self.key
      :unconstrained_deep
    end

    # @return [Types::PAnyType] the puppet type used when validating the options hash
    def self.options_t
      @options_t ||= Types::TypeParser.singleton.parse('Hash[String[1],Any]')
    end

    MergeStrategy.add_strategy(self)
  end

  # Same as {UnconstrainedDeepMergeStrategy} but with reverse priority of merged elements.
  # (needed for backward compatibility with Hiera v3)
  class ReverseDeepMergeStrategy < UnconstrainedDeepMergeStrategy
    INSTANCE = self.new(EMPTY_HASH)

    def self.key
      :reverse_deep
    end

    def checked_merge(e1, e2)
      super(e2, e1)
    end

    MergeStrategy.add_strategy(self)
  end
end
