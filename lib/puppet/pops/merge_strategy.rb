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

    # Finds the merge strategy for the given _merge_, creates an instance of it and returns that instance.
    #
    # @param merge [String|Symbol|Hash<String,Object>] The merge strategy. Can be a string or symbol denoting the key
    #   identifier or a hash with options where the key 'strategy' denotes the key
    # @return [MergeStrategy] The matching merge strategy
    #
    def self.strategy(merge)
      TypeAsserter.assert_instance_of("MergeStrategies.merge 'merge' parameter", merge_t, merge)
      if merge.is_a?(Hash)
        merge_strategy = merge['strategy']
        if merge_strategy.nil?
          raise ArgumentError, "The hash given as 'merge' must contain the name of a strategy in string form for the key 'strategy'"
        end
        merge_options  = merge
      else
        merge_strategy = merge
        merge_options  = {}
      end
      strategy = strategies[merge_strategy.to_sym]
      raise ArgumentError, "Unknown merge strategy: '#{merge_strategy}'" if strategy.nil?
      strategy.new(merge_options)
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
      unless MergeStrategy > strategy_class
        raise ArgumentError, "MergeStrategies.add_strategy 'strategy_class' must be a 'MergeStrategy' class. Got #{strategy_class}"
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
      assert_type('merge_options', options_t, options)
      @options = options
    end

    # Merges the elements of _e1_ and _e2_ accoring to the implemented strategy and options given when this
    # instance was created
    #
    # @param e1 [Object] The first element
    # @param e2 [Object] The second element
    # @return [Object] The result of the merge
    #
    def merge(e1, e2)
      checked_merge(
        assert_type('e1', value_t, e1),
        assert_type('e2', value_t, e2))
    end

    # Converts a single value to the type expeced when peforming a merge of two elements
    # @param value [Object] the value to convert
    # @return [Object] the converted value
    def convert_value(value)
      value
    end

    protected

    def options
      @options
    end

    # Returns the type used to validate the options hash
    #
    # @return [Puppet::Pops::Types::PStructType] the puppet type
    #
    def options_t
      @options_t ||=TypeParser.new.parse("Struct[{strategy=>Optional[Pattern[#{self.class.key}]]}]")
    end

    # Returns the type used to validate the options hash
    #
    # @return [Puppet::Pops::Types::PAnyType] the puppet type
    #
    def value_t
      raise NotImplementedError, "Subclass must implement 'value_t'"
    end

    def checked_merge(e1, e2)
      raise NotImplementedError, "Subclass must implement 'checked_merge(e1,e2)'"
    end

    def assert_type(param, type, value)
      TypeAsserter.assert_instance_of(param, type, value)
    end
  end

  # Produces a new hash by merging hash e1 with hash e2 in such a way that the values of duplicate keys
  # will be those of e1
  #
  class HashMergeStrategy < MergeStrategy
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
      @value_t ||= Puppet::Pops::Types::TypeParser.new.parse('Hash[String,Data]')
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

    protected

    def value_t
      @value_t ||= Puppet::Pops::Types::TypeParser.new.parse('Variant[Scalar,Array[Data]]')
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
  #   - 'unpack_arrays' Set to string value used as a deliminator to join all array values and then split them again. Default is _undef_
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
  # :unpack_arrays => The purpose of this is to permit compound elements to be passed
  #   in as strings and to be converted into discrete array elements
  #   irsource = {:x => ['1,2,3', '4']}
  #   dest   = {:x => ['5','6','7,8']}
  #   dest.deep_merge!(source, {:unpack_arrays => ','})
  #   Results: {:x => ['1','2','3','4','5','6','7','8']}
  #   Why: If receiving data from an HTML form, this makes it easy for a checkbox
  #    to pass multiple values from within a single HTML element
  #
  # :merge_hash_arrays => merge hashes within arrays
  #   source = {:x => [{:y => 1}]}
  #   dest   = {:x => [{:z => 2}]}
  #   dest.deep_merge!(source, {:merge_hash_arrays => true})
  #   Results: {:x => [{:y => 1, :z => 2}]}
  #
  class DeepMergeStrategy < MergeStrategy
    def self.key
      :deep
    end

    def checked_merge(e1, e2)
      dm_options = { :preserve_unmergeables => false }
      options.each_pair { |k,v| dm_options[k.to_sym] = v unless k == 'strategy' }
      # e2 (the destination) is dup'ed to avoid that the passed in object mutates
      DeepMerge.deep_merge!(e1, e2.dup, dm_options)
    end

    protected

    # Returns a type that allows all deep_merge options except 'preserve_unmergeables' since we force
    # the setting of that option to false
    #
    # @return [Puppet::Pops::Types::PAnyType] the puppet type used when validating the options hash
    def options_t
      @options_t ||= Puppet::Pops::Types::TypeParser.new.parse('Struct[{'\
          "strategy=>Optional[Pattern[#{self.class.key}]],"\
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
