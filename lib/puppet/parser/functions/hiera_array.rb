require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera_array, :type => :rvalue, :arity => -2,:doc => "Returns all 
  matches throughout the hierarchy --- not just the first match --- as a flattened array of unique values.
  If any of the matched values are arrays, they're flattened and included in the results.
  
  In addition to the required `key` argument, `hiera_array` accepts two additional 
  arguments:
  
  - a `default` argument in the second position, providing a string or array to be returned 
    in the absence of  matches to the `key` argument
  - an `override` argument in the third position, providing a data source to consult for 
    matching values, even if it would not ordinarily be part of the matched hierarchy. 
    If Hiera doesn't find a matching key in the named override data source, it will 
    continue to search through the rest of the hierarchy.
    
  If any matched value is a hash, puppet will raise a type mismatch error.

  More thorough examples of `hiera` are available at:  
  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
  ") do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :array)
  end
end

