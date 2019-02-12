# Returns the index (or key in a hash) to a first-found value in an `Iterable` value.
#
# When called with a  [lambda](https://puppet.com/docs/puppet/latest/lang_lambdas.html)
# the lambda is called repeatedly using each value in a data structure until the lambda returns a "truthy" value which
# makes the function return the index or key, or if the end of the iteration is reached, undef is returned.
#
# This function can be called in two different ways; with a value to be searched for, or with
# a lambda that determines if an entry in the iterable matches.
#
# When called with a lambda the function takes two mandatory arguments, in this order:
#
# 1. An array, hash, string, or other iterable object that the function will iterate over.
# 2. A lambda, which the function calls for each element in the first argument. It can request one (value) or two (index/key, value) parameters.
#
# @example Using the `index` function
#
# `$data.index |$parameter| { <PUPPET CODE BLOCK> }`
#
# or
#
# `index($data) |$parameter| { <PUPPET CODE BLOCK> }`
#
# @example Using the `index` function with an Array and a one-parameter lambda
#
# ```puppet
# $data = ["routers", "servers", "workstations"]
# notice $data.index |$value| { $value == 'servers' } # notices 1
# notice $data.index |$value| { $value == 'hosts'  }  # notices undef
# ```
#
# @example Using the `index` function with a Hash and a one-parameter lambda
#
# ```puppet
# $data = {types => ["routers", "servers", "workstations"], colors => ['red', 'blue', 'green']}
# notice $data.index |$value| { 'servers' in $value } # notices 'types'
# notice $data.index |$value| { 'red' in $value }     # notices 'colors'
# ```
# Note that the lambda gets the value and not an array with `[key, value]` as in other
# iterative functions.
#
# Using a lambda that accepts two values works the same way, it simply gets the index/key 
# as the first parameter, and the value as the second.
#
# @example Using the `index` function with an Array and a two-parameter lambda
#
# ```puppet
# # Find the first even numbered index that has a non String value
# $data = [key1, 1, 3, 5]
# notice $data.index |$idx, $value| { $idx % 2 == 0 and $value !~ String } # notices 2
# ```
#
# When called on a `String`, the lambda is given each character as a value. What is typically wanted is to
# find a sequence of characters which is achieved by calling the function with a value to search for instead
# of giving a lambda.
#
#
# @example Using the `index` function with a String, search for first occurrence of a sequence of characters
#
# ```puppet
# # Find first occurrence of 'ah'
# $data = "blablahbleh"
# notice $data.index('ah') # notices 5
# ```
#
# @example Using the `index` function with a String, search for first occurrence of a regular expression
#
# ```puppet
# # Find first occurrence of 'la' or 'le'
# $data = "blablahbleh"
# notice $data.index(/l(a|e)/ # notices 1
# ```
#
# When searching in a `String` with a given value that is neither `String` nor `Regexp` the answer is always `undef`.
# When searching in any other iterable, the value is matched against each value in the iteration using strict
# Ruby `==` semantics. If Puppet Language semantics are wanted (where string compare is case insensitive) use a
# lambda and the `==` operator in Puppet.
#
# @example Using the `index` function to search for a given value in an Array
#
# ```puppet
# $data = ['routers', 'servers', 'WORKstations']
# notice $data.index('servers')      # notices 1
# notice $data.index('workstations') # notices undef (not matching case)
# ```
#
# For an general examples that demonstrates iteration, see the Puppet
# [iteration](https://puppet.com/docs/puppet/latest/lang_iteration.html)
# documentation.
#
# @since 6.3.0
#
Puppet::Functions.create_function(:index) do
  dispatch :index_Hash_2 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[2,2]', :block
  end

  dispatch :index_Hash_1 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[1,1]', :block
  end

  dispatch :index_Enumerable_2 do
    param 'Iterable', :enumerable
    block_param 'Callable[2,2]', :block
  end

  dispatch :index_Enumerable_1 do
    param 'Iterable', :enumerable
    block_param 'Callable[1,1]', :block
  end

  dispatch :string_index do
    param 'String', :str
    param 'Variant[String,Regexp]', :match
  end

  dispatch :index_value do
    param 'Iterable', :enumerable
    param 'Any', :match
  end


  def index_Hash_1(hash)
    hash.each_pair { |x, y| return x if yield(y)  }
    nil
  end

  def index_Hash_2(hash)
    hash.each_pair.any? { |x, y| return x if yield(x, y) }
    nil
  end

  def index_Enumerable_1(enumerable)
    enum = Puppet::Pops::Types::Iterable.asserted_iterable(self, enumerable)
    if enum.hash_style?
      enum.each { |entry| return entry[0] if yield(entry[1]) }
    else
      enum.each_with_index { |e, i| return i if yield(e) }
    end
    nil
  end

  def index_Enumerable_2(enumerable)
    enum = Puppet::Pops::Types::Iterable.asserted_iterable(self, enumerable)
    if enum.hash_style?
      enum.each { |entry| return entry[0] if yield(*entry) }
    else
      enum.each_with_index { |e, i| return i if yield(i, e) }
    end
    nil
  end

  def string_index(str, match)
    str.index(match)
  end

  def index_value(enumerable, match)
    enum = Puppet::Pops::Types::Iterable.asserted_iterable(self, enumerable)
    if enum.hash_style?
      enum.each { |entry| return entry[0] if entry[1] == match }
    else
      enum.each_with_index { |e, i| return i if e == match }
    end
    nil
  end
end
