# Reverses the order of the elements of something that is iterable and optionally runs a
# [lambda](https://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html) for each
# element.
#
# This function takes one to two arguments:
#
# 1. An `Iterable` that the function will iterate over.
# 2. An optional lambda, which the function calls for each element in the first argument. It must
#    request one parameter.
#
# @example Using the `reverse_each` function
#
# ```puppet
# $data.reverse_each |$parameter| { <PUPPET CODE BLOCK> }
# ```
#
# or
#
# ```puppet
# $reverse_data = $data.reverse_each
# ```
#
# or
#
# ```puppet
# reverse_each($data) |$parameter| { <PUPPET CODE BLOCK> }
# ```
#
# or
#
# ```puppet
# $reverse_data = reverse_each($data)
# ```
#
# When no second argument is present, Puppet returns an `Iterable` that represents the reverse
# order of its first argument. This allows methods on `Iterable` to be chained.
#
# When a lambda is given as the second argument, Puppet iterates the first argument in reverse
# order and passes each value in turn to the lambda, then returns `undef`.
#
# @example Using the `reverse_each` function with an array and a one-parameter lambda
#
# ```puppet
# # Puppet will log a notice for each of the three items
# # in $data in reverse order.
# $data = [1,2,3]
# $data.reverse_each |$item| { notice($item) }
# ```
#
# When no second argument is present, Puppet returns a new `Iterable` which allows it to
# be directly chained into another function that takes an `Iterable` as an argument.
#
# @example Using the `reverse_each` function chained with a `map` function.
#
# ```puppet
# # For the array $data, return an array containing each
# # value multiplied by 10 in reverse order
# $data = [1,2,3]
# $transformed_data = $data.reverse_each.map |$item| { $item * 10 }
# # $transformed_data is set to [30,20,10]
# ```
#
# @example Using `reverse_each` function chained with a `map` in alternative syntax
#
# ```puppet
# # For the array $data, return an array containing each
# # value multiplied by 10 in reverse order
# $data = [1,2,3]
# $transformed_data = map(reverse_each($data)) |$item| { $item * 10 }
# # $transformed_data is set to [30,20,10]
# ```
#
# @since 4.4.0
#
Puppet::Functions.create_function(:reverse_each) do
  dispatch :reverse_each do
    param 'Iterable', :iterable
  end

  dispatch :reverse_each_block do
    param 'Iterable', :iterable
    block_param 'Callable[1,1]', :block
  end

  def reverse_each(iterable)
    # produces an Iterable
    Puppet::Pops::Types::Iterable.asserted_iterable(self, iterable).reverse_each
  end

  def reverse_each_block(iterable, &block)
    Puppet::Pops::Types::Iterable.asserted_iterable(self, iterable).reverse_each(&block)
    nil
  end
end
