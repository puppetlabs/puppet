# Runs a [lambda](http://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
# repeatedly using each value in a data structure until the lambda returns a non "truthy" value which
# makes the function return `false`, or if the end of the iteration is reached, `true` is returned.
#
# This function takes two mandatory arguments, in this order:
#
# 1. An array, hash, or other iterable object that the function will iterate over.
# 2. A lambda, which the function calls for each element in the first argument. It can
# request one or two parameters.
#
# @example Using the `all` function
#
# `$data.all |$parameter| { <PUPPET CODE BLOCK> }`
#
# or
#
# `all($data) |$parameter| { <PUPPET CODE BLOCK> }`
#
# @example Using the `all` function with an Array and a one-parameter lambda
#
# ```puppet
# # For the array $data, run a lambda that checks that all values are multiples of 10
# $data = [10, 20, 30]
# notice $data.all |$item| { $item % 10 == 0 }
# ```
#
# Would notice `true`.
#
# When the first argument is a `Hash`, Puppet passes each key and value pair to the lambda
# as an array in the form `[key, value]`.
#
# @example Using the `all` function with a `Hash` and a one-parameter lambda
#
# ```puppet
# # For the hash $data, run a lambda using each item as a key-value array
# $data = { 'a_0'=> 10, 'b_1' => 20 }
# notice $data.all |$item| { $item[1] % 10 == 0  }
# ```
#
# Would notice `true` if all values in the hash are multiples of 10.
#
# When the lambda accepts two arguments, the first argument gets the index in an array
# or the key from a hash, and the second argument the value.
#
#
# @example Using the `all` function with a hash and a two-parameter lambda
#
# ```puppet
# # Check that all values are a multiple of 10 and keys start with 'abc'
# $data = {abc_123 => 10, abc_42 => 20, abc_blue => 30}
# notice $data.all |$key, $value| { $value % 10 == 0  and $key =~ /^abc/ }
# ```
#
# Would notice true.
#
# For an general examples that demonstrates iteration, see the Puppet
# [iteration](https://docs.puppetlabs.com/puppet/latest/reference/lang_iteration.html)
# documentation.
#
# @since 5.2.0
#
Puppet::Functions.create_function(:all) do
  dispatch :all_Hash_2 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[2,2]', :block
  end

  dispatch :all_Hash_1 do
    param 'Hash[Any, Any]', :hash
    block_param 'Callable[1,1]', :block
  end

  dispatch :all_Enumerable_2 do
    param 'Iterable', :enumerable
    block_param 'Callable[2,2]', :block
  end

  dispatch :all_Enumerable_1 do
    param 'Iterable', :enumerable
    block_param 'Callable[1,1]', :block
  end

  def all_Hash_1(hash)
    hash.each_pair.all? { |x| yield(x) }
  end

  def all_Hash_2(hash)
    hash.each_pair.all? { |x,y| yield(x,y) }
  end

  def all_Enumerable_1(enumerable)
    Puppet::Pops::Types::Iterable.asserted_iterable(self, enumerable).all? { |e| yield(e) }
  end

  def all_Enumerable_2(enumerable)
    enum = Puppet::Pops::Types::Iterable.asserted_iterable(self, enumerable)
    if enum.hash_style?
      enum.all? { |entry| yield(*entry) }
    else
      enum.each_with_index { |e, i| return false unless yield(i, e) }
      true
    end
  end
end
