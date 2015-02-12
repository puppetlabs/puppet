require 'hiera/puppet_function'

# Returns all matches throughout the hierarchy --- not just the first match --- as a flattened array of unique values.
#  If any of the matched values are arrays, they're flattened and included in the results.
#
#  The function can be called in one of three ways:
#  1. Using 1 to 3 arguments where the arguments are:
#     'key'      [String] Required
#           The key to lookup.
#     'default`  [Any] Optional
#           A value to return when there's no match for `key`. Optional
#     `override` [Any] Optional
#           An argument in the third position, providing a data source
#           to consult for matching values, even if it would not ordinarily be
#           part of the matched hierarchy. If Hiera doesn't find a matching key
#           in the named override data source, it will continue to search through the
#           rest of the hierarchy.
#
#  2. Using a 'key' and an optional 'override' parameter like in #1 but with a block to
#     provide the default value. The block is called with one parameter (the key) and
#     should return the value.
#
#  3. Like #1 but with all arguments passed in an array.
#  If any matched value is a hash, puppet will raise a type mismatch error.
#
#  More thorough examples of `hiera` are available at:
#  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
Puppet::Functions.create_function(:hiera_array, Hiera::PuppetFunction) do
  init_dispatch

  def merge_type
    :array
  end
end
