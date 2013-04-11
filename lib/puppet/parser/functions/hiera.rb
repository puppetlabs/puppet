require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera, :type => :rvalue, :arity => -2, :doc => "Performs a
  standard priority lookup and returns the most specific value for a given key.
  The returned value can be data of any type (strings, arrays, or hashes). 

  In addition to the required `key` argument, `hiera` accepts two additional
  arguments:

  - a `default` argument in the second position, providing a value to be
    returned in the absence of matches to the `key` argument
  - an `override` argument in the third position, providing a data source
    to consult for matching values, even if it would not ordinarily be
    part of the matched hierarchy. If Hiera doesn't find a matching key
    in the named override data source, it will continue to search through the
    rest of the hierarchy.

  More thorough examples of `hiera` are available at:  
  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
  ") do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :priority)
  end
end

