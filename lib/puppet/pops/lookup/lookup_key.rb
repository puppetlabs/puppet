require_relative 'sub_lookup'

module Puppet::Pops
module Lookup
# @api private
class LookupKey
  include SubLookup

  attr_reader :module_name, :root_key, :segments

  def initialize(key)
    segments = split_key(key) { |problem| Puppet::DataBinding::LookupError.new(_("%{problem} in key: '%{key}'") % { problem: problem, key: key }) }
    root_key = segments.shift.freeze
    qual_index = root_key.index(DOUBLE_COLON)

    @key = key
    @module_name = qual_index.nil? ? nil : root_key[0..qual_index-1].freeze
    @root_key = root_key
    @segments = segments.empty? ? nil : segments.freeze
  end

  def dig(lookup_invocation, value)
    @segments.nil? ? value : sub_lookup(@key, lookup_invocation, @segments, value)
  end

  # Prunes a found root value with respect to subkeys in this key. The given _value_ is returned untouched
  # if this key has no subkeys. Otherwise an attempt is made to create a Hash or Array that contains only the
  # path to the appointed value and that value.
  #
  # If subkeys exists and no value is found, then this method will return `nil`, an empty `Array` or an empty `Hash`
  # to enable further merges to be applied. The returned type depends on the given _value_.
  #
  # @param value [Object] the value to prune
  # @return the possibly pruned value
  def prune(value)
    if @segments.nil?
      value
    else
      pruned = @segments.reduce(value) do |memo, segment|
        memo.is_a?(Hash) || memo.is_a?(Array) && segment.is_a?(Integer) ? memo[segment] : nil
      end
      if pruned.nil?
        case value
        when Hash
          EMPTY_HASH
        when Array
          EMPTY_ARRAY
        else
          nil
        end
      else
        undig(pruned)
      end
    end
  end

  # Create a structure that can be dug into using the subkeys of this key in order to find the
  # given _value_. If this key has no subkeys, the _value_ is returned.
  #
  # @param value [Object] the value to wrap in a structure in case this value has subkeys
  # @return [Object] the possibly wrapped value
  def undig(value)
    @segments.nil? ? value : segments.reverse.reduce(value) do |memo, segment|
      if segment.is_a?(Integer)
        x = []
        x[segment] = memo
      else
        x = { segment => memo }
      end
      x
    end
  end

  def to_a
    unless instance_variable_defined?(:@all_segments)
      a = [@root_key]
      a += @segments unless @segments.nil?
      @all_segments = a.freeze
    end
    @all_segments
  end

  def eql?(v)
    v.is_a?(LookupKey) && @key == v.to_s
  end
  alias == eql?

  def hash
    @key.hash
  end

  def to_s
    @key
  end

  LOOKUP_OPTIONS = LookupKey.new('lookup_options')
end
end
end
