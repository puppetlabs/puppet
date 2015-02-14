require 'deep_merge/core'

module Puppet::Pops
  # Merges to objects into one based on an implemented strategy.
  #
  class MergeStrategy
    TypeAsserter = Puppet::Pops::Types::TypeAsserter
    TypeParser = Puppet::Pops::Types::TypeParser

    # The type used for validation of the _merge_ argument
    def self.merge_t
      @@merge_t ||=  TypeParser.new.parse("Variant[String[1],Runtime[ruby,'Symbol'],Hash[Variant[String[1],Runtime[ruby,'Symbol']],Scalar,1]]")
    end
    private_class_method :merge_t

    def self.strategies
      @@strategies ||= {}
    end
    private_class_method :strategies

    # Finds the merge strategy for the given key and returns it.
    #
    # @param merge_strategy_key [Symbol] The merge strategy key
    # @return [MergeStrategy] The matching merge strategy
    #
    def self.strategy(merge_strategy_key)
      strategy = strategies[merge_strategy_key]
      raise ArgumentError, "Unknown merge strategy: '#{merge_strategy_key}'" if strategy.nil?
      strategy
    end

    # Returns the list of merge strategy keys known to this class
    #
    # @return [Array<Symbol>] List of strategy keys
    #
    def self.strategy_keys
      strategies.keys
    end

    # Adds a new merge strategy to the map of strategies known to this class
    #
    # @param strategy_class [Class<MergeStrategy>] The class of the added strategy
    #
    def self.add_strategy(strategy_class)
      raise ArgumentError, "MergeStrategies.add_strategy 'strategy_class' must be a 'MergeStrategy' class. Got #{strategy_class}" unless MergeStrategy > strategy_class
      s = strategy_class.new
      strategies[s.key] = s
      nil
    end

    # Finds a merge strategy that corresponds to the given _merge_ argument and delegates the task of merging the elements of _e1_ and _e2_ to it.
    #
    # @param e1 [Object] The first element
    # @param e2 [Object] The second element
    # @param merge [String|Symbol|Hash<String,Object>] The merge strategy. Can be a string or symbol denoting the key identifier or a hash with options where the key 'strategy' denotes the key
    # @return [Object] The result of the merge
    #
    def self.merge(e1, e2, merge)
      TypeAsserter.assert_instance_of("MergeStrategies.merge 'merge' parameter", merge_t, merge)
      if merge.is_a?(Hash)
        merge_strategy = merge['strategy']
        raise ArgumentError, "MergeStrategies.merge 'merge' parameter must contain a 'strategy' of type String" if merge_strategy.nil?
        merge_options  = merge
      else
        merge_strategy = merge
        merge_options  = {}
      end
      strategy(merge_strategy.to_sym).merge(e1, e2, merge_options)
    end

    # Merges the elements of _e1_ and _e2_ accoring to the implemented strategy
    #
    # @param e1 [Object] The first element
    # @param e2 [Object] The second element
    # @param merge_options [Hash<String,Object>] Merge options
    # @return [Object] The result of the merge
    #
    def merge(e1, e2, merge_options)
      checked_merge(
        assert_type('e1', value_t, e1),
        assert_type('e2', value_t, e2),
        assert_type('merge_options', options_t, merge_options))
    end

    protected

    # Returns the symbolic key identifier for this strategy
    #
    # @return [Symbol] The symbolic key
    #
    def key
      raise NotImplementedError, 'Subclass must implement key'
    end

    # Returns the type used to validate the options hash
    #
    # @return [Puppet::Pops::Types::PStructType] the puppet type
    #
    def options_t
      @options_t ||=TypeParser.new.parse("Struct[{strategy=>Optional[Pattern[#{key}]]}]")
    end

    # Returns the type used to validate the options hash
    #
    # @return [Puppet::Pops::Types::PAnyType] the puppet type
    #
    def value_t
      raise NotImplementedError.new('Subclass must implement value_t')
    end

    def checked_merge(e1, e2, options)
      raise NotImplementedError.new('Subclass must implement checked_merge(e1,e2,options)')
    end

    def assert_type(param, type, value)
      TypeAsserter.assert_instance_of(param, type, value)
    end
  end

  # Performs a native Hash merge
  #
  class HashMergeStrategy < MergeStrategy
    # Merges hash e1 onto hash e2 in such a way that if the values of duplicate keys
    # will be those of e1
    #
    # @param e1 [Hash<String,Object>] The hash that will act as the source of the merge
    # @param e2 [Hash<String,Object>] The hash that will act as the receiver for the merge
    # @return [Hash<String,Object]] The merged hash
    # @see Hash#merge
    def checked_merge(e1, e2, options)
      e2.merge(e1)
    end

    def key
      :hash
    end

    protected

    def value_t
      @value_t ||= Puppet::Pops::Types::TypeParser.new.parse('Hash[String,Data]')
    end

    MergeStrategy.add_strategy(self)
  end

  # Merges two values that must be either scalar or arrays into a unique set of values.
  #
  class UniqueMergeStrategy < MergeStrategy
    # Merges two values that must be either scalar or arrays into a unique set of values.
    #
    # Scalar values will be converted into a one element arrays and array values will be flattened
    # prior to forming the unique set. The order of the elements is preserved with e1 being the
    # first contributor of elements and e2 the second.
    #
    # @param e1 [Array<Object>] The first array
    # @param e2 [Array<Object>] The second array
    # @return [Array<Object>] The unique set of elements
    #
    def checked_merge(e1, e2, options)
      to_flat_a(e1) | to_flat_a(e2)
    end

    def key
      :unique
    end

    protected

    def value_t
      @value_t ||= Puppet::Pops::Types::TypeParser.new.parse('Variant[Scalar,Array[Data]]')
    end

    def to_flat_a(e)
      e.is_a?(Array) ? e.flatten : [e]
    end

    MergeStrategy.add_strategy(self)
  end

  # Performs a deep merge. The arguments can be either Hash or Array
  #
  # @see https://github.com/danielsdeleo/deep_merge
  #
  class DeepMergeStrategy < MergeStrategy
    def checked_merge(e1, e2, options)
      # e1 (the destination) is cloned to avoid that the passed in object mutates
      DeepMerge.deep_merge!(e1, e2.clone, { :preserve_unmergeables => false }.merge(options))
    end

    def key
      :deep
    end

    protected

    # Returns a type that allows all deep_merge options except 'preserve_unmergeables' since we force
    # the setting of that option to false
    #
    # @return [Puppet::Pops::Types::PAnyType] the puppet type used when validating the options hash
    def options_t
      @options_t ||= Puppet::Pops::Types::TypeParser.new.parse('Struct[{'\
          "strategy=>Optional[Pattern[#{key}]],"\
          'knockout_prefix=>Optional[String],'\
          'merge_debug=>Optional[Boolean],'\
          'merge_hash_arrays=>Optional[Boolean],'\
          'sort_merge_arrays=>Optional[Boolean],'\
          'unpack_arrays=>Optional[String]'\
          '}]')
    end

    def value_t
      @value_t ||= Puppet::Pops::Types::TypeParser.new.parse('Variant[Array[Data],Hash[String,Data]]')
    end

    MergeStrategy.add_strategy(self)
  end
end
