require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera, :type => :rvalue, :arity => -2, :doc => "Performs a
  standard priority lookup and returns the most specific value for a given key.
  The returned value can be data of any type (strings, arrays, or hashes)

  The function can be called in one of three ways:
  1. Using 1 to 3 arguments where the arguments are:
     'key'      [String] Required
           The key to lookup.
     'default`  [Any] Optional
           A value to return when there's no match for `key`. Optional
     `override` [Any] Optional
           An argument in the third position, providing a data source
           to consult for matching values, even if it would not ordinarily be
           part of the matched hierarchy. If Hiera doesn't find a matching key
           in the named override data source, it will continue to search through the
           rest of the hierarchy.

  2. Using a 'key' and an optional 'override' parameter like in #1 but with a block to
     provide the default value. The block is called with one parameter (the key) and
     should return the value. This option can only be used with the 3x future parser or
     from 4.0.0.

  3. Like #1 but with all arguments passed in an array.

  More thorough examples of `hiera` are available at:
  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
  ") do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :priority)
  end
end

