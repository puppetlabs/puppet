# Runs a [lambda](http://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
# recursively and repeatedly using each value in a data structure, then returns the values unchanged.
#
# This function takes two mandatory arguments and one optional, in this order:
#
# 1. An `Array`, `Hash`, or `Iterator` that the function will iterate over.
# 2. An optional hash with the options:
#    * include => `Optional[T]` # only yield values matching the type, default `Any` (include all)
#    * exclude => `Optional[T]` # only yield values that do not match the filter type, default `undef` (exclude none)
# 3. A lambda, which the function calls for each element in the first argument. It must
#    accept one or two arguments; either `$path`, and `$value`, or just `$value`.
#
# @example Using the `tree_each` function
#
# `$data.tree_each |$path, $value| { <PUPPET CODE BLOCK> }`
#
# or
#
# `tree_each($data) |$path, $value| { <PUPPET CODE BLOCK> }`
#
# The parameter `$path` is always given as an `Array` containing the path that when applied to
# the tree as `$data.dig(*$path) yields the `$value`.
# The `$value` is the current value.
#
# For `Array` values, the path will contain `Integer` entries with the array index,
# and for `Hash` values, the path will contain the hash key, which may be `Any` value.
#
# The tree is walked in depth first order, yielding each `Array` and `Hash` and each
# entry.
#
# Typical use of the `tree_each` function include:
# * a more efficient way to iterate over a tree than first using `flatten` on an array
#   as that requires a new (potentially very large) array to be created
# * when a tree needs to be transformed and 'pretty printed' in a template
# * avoiding having to write a special recursive function when tree contains hashes (flatten does
#   not work on hashes)
#
# The `include` and `exclude` type filters are general purpose and can be used to
# tailor what is being yielded to the given lambda. The most common use cases for this
# are:
#
# * Only yield the values in arrays and hashes, not the arrays and hashes themselves. For this
#   the `exclude` should be set to `Collection`. Puppet will still recurse through the entire structure
#   but will not call the lambda for collections.
# * Only yield the arrays and hashes and skip all other contents in those. For this the
#   `include` should be set to `Collection`.
#
# @example A flattened iteration over a tree excluding Collections
#
# ~~~ puppet
# $data = [1, 2, [3, [4, 5]]]
# $data.tree_each({exclude => Collection}) |$v| { notice "$v" }
# ~~~
#
# This would call the lambda 5 times with with the following values in sequence: `1`, `2`, `3`, `4`, `5`
#
# @example A flattened iteration over a tree (including Collections by default)
#
# ~~~ puppet
# $data = [1, 2, [3, [4, 5]]]
# $data.tree_each |$v| { notice "$v" }
# ~~~
#
# This would call the lambda 7 times with the following values in sequence:
# `1`, `2`, `[3, [4, 5]]`, `3`, `[4, 5]`, `4`, `5`
#
# @example A flattened iteration over a tree (including only Collections)
#
# ~~~ puppet
# $data = [1, 2, [3, [4, 5]]]
# $data.tree_each({include => Collection} |$v| { notice "$v" }
# ~~~
#
# This would call the lambda 2 times with the following values in sequence:
# `[3, [4, 5]]`, `[4, 5]`

# Any Puppet Type system data type can be used to filter.
#
# **Pruning** (dynamically deciding if a container's content should be processed or not) is possible
# by making the lambda return a `Boolean` value of `true` when given an `Array` or `Hash`.
# All other values are taken to mean normal processing. Returning `true` when the value is neither
# an `Array` nor a `Hash` has no effect as there is nothing to prune.
#
# @example pruning a tree
# 
# ~~~ puppet
# $tree = [
#  { name => 'user1', status => 'inactive', id => '10'},
#  { name => 'user2', status => 'active', id => '20'}
# ]
# $tree.tree_each |$path, $v| {
#   if $v =~ Hash { next($v[status] != 'active') }
#   notice "${path[-1]} is ${v}"
# }
# ~~~
#
# Would notice these three values in turn:
# * "name is user2"
# * "status is active"
# * "id is 20"
#
#
# For general examples that demonstrates iteration see the Puppet
# [iteration](https://docs.puppetlabs.com/puppet/latest/reference/lang_iteration.html)
# documentation.
#
# @since 5.0.0
#
Puppet::Functions.create_function(:tree_each) do

  local_types do
    type "OptionsType  = Struct[{\
      container_type => Optional[Type],\
      include_root   => Optional[Boolean],
      include_containers => Optional[Boolean],\
      include_values => Optional[Boolean],\
      order => Optional[Enum[depth_first, breadth_first]]\
    }]"
  end

#  dispatch :tree_Hash2 do
#    param 'Hash[Any, Any]', :tree
#    optional_param 'OptionsType', :options
#    block_param 'Callable[2,2]', :block
#  end
#
#  dispatch :tree_Hash1 do
#    param 'Hash[Any, Any]', :tree
#    optional_param 'OptionsType', :options
#    block_param 'Callable[1,1]', :block
#  end

  dispatch :tree_Enumerable2 do
    param 'Variant[Iterator, Array, Hash]', :tree
    optional_param 'OptionsType', :options
    block_param 'Callable[2,2]', :block
  end

  dispatch :tree_Enumerable1 do
    param 'Variant[Iterator, Array, Hash]', :tree
    optional_param 'OptionsType', :options
    block_param 'Callable[1,1]', :block
  end

  def tree_Enumerable1(enum, options = {}, &block)
    iterator(enum, options).each {|_, v| yield(v) }
    enum
  end

  def tree_Enumerable2(enum, options = {}, &block)
    iterator(enum, options).each {|path, v| yield(path, v) }
    enum
  end

  def iterator(enum, options)
    if depth_first?(options)
      Puppet::Pops::Types::Iterable::DepthFirstTreeIterator.new(enum, options)
    else
      Puppet::Pops::Types::Iterable::BreadthFirstTreeIterator.new(enum, options)
    end
  end

  def depth_first?(options)
    (order = options['order']).nil? ? true : order == 'depth_first'
  end
end
