# frozen_string_literal: true

# Groups the collection by result of the block. Returns a hash where the keys are the evaluated result from the block
# and the values are arrays of elements in the collection that correspond to the key.
Puppet::Functions.create_function(:group_by) do
  # @param collection A collection of things to group.
  # @example Group array of strings by length, results in e.g. { 1 => [a, b], 2 => [ab] }
  #   [a, b, ab].group_by |$s| { $s.length }
  # @example Group array of strings by length and index, results in e.g. {1 => ['a'], 2 => ['b', 'ab']}
  #   [a, b, ab].group_by |$i, $s| { $i%2 + $s.length }
  # @example Group hash iterating by key-value pair, results in e.g. { 2 => [['a', [1, 2]]], 1 => [['b', [1]]] }
  #   { a => [1, 2], b => [1] }.group_by |$kv| { $kv[1].length }
  # @example Group hash iterating by key and value, results in e.g. { 2 => [['a', [1, 2]]], 1 => [['b', [1]]] }
  #   { a => [1, 2], b => [1] }.group_by |$k, $v| { $v.length }
  dispatch :group_by_1 do
    required_param 'Collection', :collection
    block_param 'Callable[1,1]', :block
    return_type 'Hash'
  end

  dispatch :group_by_2a do
    required_param 'Array', :array
    block_param 'Callable[2,2]', :block
    return_type 'Hash'
  end

  dispatch :group_by_2 do
    required_param 'Collection', :collection
    block_param 'Callable[2,2]', :block
    return_type 'Hash'
  end

  def group_by_1(collection)
    collection.group_by do |item|
      yield(item)
    end.freeze
  end

  def group_by_2a(array)
    grouped = array.size.times.zip(array).group_by do |k, v|
      yield(k, v)
    end

    grouped.each_with_object({}) do |(k, v), hsh|
      hsh[k] = v.map { |item| item[1] }
    end.freeze
  end

  def group_by_2(collection)
    collection.group_by do |k, v|
      yield(k, v)
    end.freeze
  end
end
