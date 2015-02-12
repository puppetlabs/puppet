require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera_hash, :type => :rvalue, :arity => -2, :doc =>
  "Returns a merged hash of matches from throughout the hierarchy. In cases where two or
  more hashes share keys, the hierarchy  order determines which key/value pair will be
  used in the returned hash, with the pair in the highest priority data source winning.

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

  `hiera_hash` expects that all values returned will be hashes. If any of the values 
  found in the data sources are strings or arrays, puppet will raise a type mismatch error.

  More thorough examples of `hiera_hash` are available at:
  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
  ") do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :hash)
  end
end

