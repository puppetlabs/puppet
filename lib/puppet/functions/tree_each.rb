# Runs a [lambda](http://docs.puppetlabs.com/puppet/latest/reference/lang_lambdas.html)
# recursively and repeatedly using values from a data structure, then returns the unchanged data structure, or if
# a lambda is not given, returns an `Iterator` for the tree.
#
# This function takes one mandatory argument, one optional, and an optional block in this order:
#
# 1. An `Array`, `Hash`, `Iterator`, or `Object` that the function will iterate over.
# 2. An optional hash with the options:
#    * `include_containers` => `Optional[Boolean]` # default true - if containers should be given to the lambda
#    * `include_values` => `Optional[Boolean]` # default true - if non containers should be given to the lambda
#    * `include_root` => `Optional[Boolean]` # default true - if the root container should be given to the lambda
#    * `container_type` => `Optional[Type[Variant[Array, Hash, Object]]]` # a type that determines what a container is - can only
#       be set to a type that matches the default `Variant[Array, Hash, Object]`.
#    * `order` => `Enum[depth_first, breadth_first]` # default ´depth_first`, the order in which elements are visited
#    * `include_refs` => Optional[Boolean] # default `false`, if attributes in objects marked as bing of `reference` kind
#       should be included.
# 3. An optional lambda, which the function calls for each element in the first argument. It must
#    accept one or two arguments; either `$path`, and `$value`, or just `$value`.
#
# @example Using the `tree_each` function
#
# `$data.tree_each |$path, $value| { <PUPPET CODE BLOCK> }`
# `$data.tree_each |$value| { <PUPPET CODE BLOCK> }`
#
# or
#
# `tree_each($data) |$path, $value| { <PUPPET CODE BLOCK> }`
# `tree_each($data) |$value| { <PUPPET CODE BLOCK> }`
#
# The parameter `$path` is always given as an `Array` containing the path that when applied to
# the tree as `$data.dig(*$path) yields the `$value`.
# The `$value` is the value at that path.
#
# For `Array` values, the path will contain `Integer` entries with the array index,
# and for `Hash` values, the path will contain the hash key, which may be `Any` value.
# For `Object` containers, the entry is the name of the attribute (a `String`).
#
# The tree is walked in either depth-first order, or in breadth-first order under the control of the
# `order` option, yielding each `Array`, `Hash`, `Object`, and each entry/attribute.
# The default is `depth_first` which means that children are processed before siblings.
# An order of `breadth_first` means that siblings are processed before children.
#
# @example depth- or breadth-first order
#
# ```puppet
# [1, [2, 3], 4]
# ```
#
# Results in:
#
# If containers are skipped:
#
# * `depth_first` order `1`, `2`, `3`, `4` 
# * `breadth_first` order `1`, `4`,`2`, `3` 
#
# If containers and root, are included:
#
# * `depth_first` order `[1, [2, 3], 4]`, `1`, `[2, 3]`, `2`, `3`, `4` 
# * `breadth_first` order `[1, [2, 3], 4]`, `1`, `[2, 3]`, `4`, `2`, `3` 
#
# Typical use of the `tree_each` function include:
# * a more efficient way to iterate over a tree than first using `flatten` on an array
#   as that requires a new (potentially very large) array to be created
# * when a tree needs to be transformed and 'pretty printed' in a template
# * avoiding having to write a special recursive function when tree contains hashes (flatten does
#   not work on hashes)
#
# @example A flattened iteration over a tree excluding Collections
#
# ```puppet
# $data = [1, 2, [3, [4, 5]]]
# $data.tree_each({include_containers => false}) |$v| { notice "$v" }
# ```
#
# This would call the lambda 5 times with with the following values in sequence: `1`, `2`, `3`, `4`, `5`
#
# @example A flattened iteration over a tree (including containers by default)
#
# ```puppet
# $data = [1, 2, [3, [4, 5]]]
# $data.tree_each |$v| { notice "$v" }
# ```
#
# This would call the lambda 7 times with the following values in sequence:
# `1`, `2`, `[3, [4, 5]]`, `3`, `[4, 5]`, `4`, `5`
#
# @example A flattened iteration over a tree (including only non root containers)
#
# ```puppet
# $data = [1, 2, [3, [4, 5]]]
# $data.tree_each({include_values => false, include_root => false}) |$v| { notice "$v" }
# ```
#
# This would call the lambda 2 times with the following values in sequence:
# `[3, [4, 5]]`, `[4, 5]`
#
# Any Puppet Type system data type can be used to filter what is
# considered to be a container, but it must be a narrower type than one of
# the default Array, Hash, Object types - for example it is not possible to make a
# `String` be a container type.
#
# @example Only `Array` as container type
#
# ```puppet
# $data = [1, {a => 'hello', b => [100, 200]}, [3, [4, 5]]]
# $data.tree_each({container_type => Array, include_containers => false} |$v| { notice "$v" }
# ```
#
# Would call the lambda 5 times with `1`, `{a => 'hello', b => [100, 200]}`, `3`, `4`, `5`
#
# **Chaining** When calling `tree_each` without a lambda the function produces an `Iterator`
# that can be chained into another iteration. Thus it is easy to use one of:
#
# * `reverse_each` - get "leaves before root" 
# * `filter` - prune the tree
# * `map` - transform each element
# * `reduce` - produce something else
#
# Note than when chaining, the value passed on is a `Tuple` with `[path, value]`.
#
# @example Pruning a tree
#
# ```puppet
# # A tree of some complexity (here very simple for readability)
# $tree = [
#  { name => 'user1', status => 'inactive', id => '10'},
#  { name => 'user2', status => 'active', id => '20'}
# ]
# notice $tree.tree_each.filter |$v| {
#  $value = $v[1]
#  $value =~ Hash and $value[status] == active
# }
# ```
#
# Would notice `[[[1], {name => user2, status => active, id => 20}]]`, which can then be processed
# further as each filtered result appears as a `Tuple` with `[path, value]`.
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
      order => Optional[Enum[depth_first, breadth_first]],\
      include_refs   => Optional[Boolean]\
    }]"
  end

  dispatch :tree_Enumerable2 do
    param 'Variant[Iterator, Array, Hash, Object]', :tree
    optional_param 'OptionsType', :options
    block_param 'Callable[2,2]', :block
  end

  dispatch :tree_Enumerable1 do
    param 'Variant[Iterator, Array, Hash, Object]', :tree
    optional_param 'OptionsType', :options
    block_param 'Callable[1,1]', :block
  end

  dispatch :tree_Iterable do
    param 'Variant[Iterator, Array, Hash, Object]', :tree
    optional_param 'OptionsType', :options
  end

  def tree_Enumerable1(enum, options = {}, &block)
    iterator(enum, options).each {|_, v| yield(v) }
    enum
  end

  def tree_Enumerable2(enum, options = {}, &block)
    iterator(enum, options).each {|path, v| yield(path, v) }
    enum
  end

  def tree_Iterable(enum, options = {}, &block)
    Puppet::Pops::Types::Iterable.on(iterator(enum, options))
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
