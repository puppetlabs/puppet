# frozen_string_literal: true

# Returns two arrays, the first containing the elements of enum for which the block evaluates to true,
# the second containing the rest.
Puppet::Functions.create_function(:partition) do
  # @param collection A collection of things to partition.
  # @example Partition array of empty strings, results in e.g. [[''], [b, c]]
  #   ['', b, c].partition |$s| { $s.empty }
  # @example Partition array of strings using index, results in e.g. [['', 'ab'], ['b']]
  #   ['', b, ab].partition |$i, $s| { $i == 2 or $s.empty }
  # @example Partition hash of strings by key-value pair, results in e.g. [[['b', []]], [['a', [1, 2]]]]
  #   { a => [1, 2], b => [] }.partition |$kv| { $kv[1].empty }
  # @example Partition hash of strings by key and value, results in e.g. [[['b', []]], [['a', [1, 2]]]]
  #   { a => [1, 2], b => [] }.partition |$k, $v| { $v.empty }
  dispatch :partition_1 do
    required_param 'Collection', :collection
    block_param 'Callable[1,1]', :block
    return_type 'Tuple[Array, Array]'
  end

  dispatch :partition_2a do
    required_param 'Array', :array
    block_param 'Callable[2,2]', :block
    return_type 'Tuple[Array, Array]'
  end

  dispatch :partition_2 do
    required_param 'Collection', :collection
    block_param 'Callable[2,2]', :block
    return_type 'Tuple[Array, Array]'
  end

  def partition_1(collection)
    collection.partition do |item|
      yield(item)
    end.freeze
  end

  def partition_2a(array)
    partitioned = array.size.times.zip(array).partition do |k, v|
      yield(k, v)
    end

    partitioned.map do |part|
      part.map { |item| item[1] }
    end.freeze
  end

  def partition_2(collection)
    collection.partition do |k, v|
      yield(k, v)
    end.freeze
  end
end
