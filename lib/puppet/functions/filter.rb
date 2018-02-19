# Applies a [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
# to every value in a data structure and returns an array or hash containing any elements
# for which the lambda evaluates to `true`.
#
# This function takes two mandatory arguments, in this order:
#
# 1. An array, hash, or other iterable object that the function will iterate over.
# 2. A lambda, which the function calls for each element in the first argument. It can
# request one or two parameters.
#
# @example Using the `filter` function
#
# `$filtered_data = $data.filter |$parameter| { <PUPPET CODE BLOCK> }`
#
# or
#
# `$filtered_data = filter($data) |$parameter| { <PUPPET CODE BLOCK> }`
#
# When the first argument (`$data` in the above example) is an array, Puppet passes each
# value in turn to the lambda and returns an array containing the results.
#
# @example Using the `filter` function with an array and a one-parameter lambda
#
# ```puppet
# # For the array $data, return an array containing the values that end with "berry"
# $data = ["orange", "blueberry", "raspberry"]
# $filtered_data = $data.filter |$items| { $items =~ /berry$/ }
# # $filtered_data = [blueberry, raspberry]
# ```
#
# When the first argument is a hash, Puppet passes each key and value pair to the lambda
# as an array in the form `[key, value]` and returns a hash containing the results.
#
# @example Using the `filter` function with a hash and a one-parameter lambda
#
# ```puppet
# # For the hash $data, return a hash containing all values of keys that end with "berry"
# $data = { "orange" => 0, "blueberry" => 1, "raspberry" => 2 }
# $filtered_data = $data.filter |$items| { $items[0] =~ /berry$/ }
# # $filtered_data = {blueberry => 1, raspberry => 2}
#
# When the first argument is an array and the lambda has two parameters, Puppet passes the
# array's indexes (enumerated from 0) in the first parameter and its values in the second
# parameter.
#
# @example Using the `filter` function with an array and a two-parameter lambda
#
# ```puppet
# # For the array $data, return an array of all keys that both end with "berry" and have
# # an even-numbered index
# $data = ["orange", "blueberry", "raspberry"]
# $filtered_data = $data.filter |$indexes, $values| { $indexes % 2 == 0 and $values =~ /berry$/ }
# # $filtered_data = [raspberry]
# ```
#
# When the first argument is a hash, Puppet passes its keys to the first parameter and its
# values to the second parameter.
#
# @example Using the `filter` function with a hash and a two-parameter lambda
#
# ```puppet
# # For the hash $data, return a hash of all keys that both end with "berry" and have 
# # values less than or equal to 1
# $data = { "orange" => 0, "blueberry" => 1, "raspberry" => 2 }
# $filtered_data = $data.filter |$keys, $values| { $keys =~ /berry$/ and $values <= 1 }
# # $filtered_data = {blueberry => 1}
# ```
#
# @since 4.0.0
#
Puppet::Functions.create_function(:filter) do
  dispatch :filter_Hash_2 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[2,2]', :block
  end

  dispatch :filter_Hash_1 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[1,1]', :block
  end

  dispatch :filter_Enumerable_2 do
    param 'Iterable', :enumerable
    block_param 'Callable[2,2]', :block
  end

  dispatch :filter_Enumerable_1 do
    param 'Iterable', :enumerable
    block_param 'Callable[1,1]', :block
  end

  def filter_Hash_1(hash)
    result = hash.select {|x, y| yield([x, y]) == true }
    # Ruby 1.8.7 returns Array
    result = Hash[result] unless result.is_a? Hash
    result
  end

  def filter_Hash_2(hash)
    result = hash.select {|x, y| yield(x, y) == true }
    # Ruby 1.8.7 returns Array
    result = Hash[result] unless result.is_a? Hash
    result
  end

  def filter_Enumerable_1(enumerable)
    result = []
    enum = Puppet::Pops::Types::Iterable.asserted_iterable(self, enumerable)
    begin
      loop do
        it = enum.next
        if yield(it) == true
          result << it
        end
      end
    rescue StopIteration
    end
    result
  end

  def filter_Enumerable_2(enumerable)
    enum = Puppet::Pops::Types::Iterable.asserted_iterable(self, enumerable)
    if enum.hash_style?
      result = {}
      enum.each { |k, v| result[k] = v if yield(k, v) == true }
      result
    else
      result = []
      begin
        index = 0
        loop do
          it = enum.next
          if yield(index, it) == true
            result << it
          end
          index += 1
        end
      rescue StopIteration
      end
      result
    end
  end
end
