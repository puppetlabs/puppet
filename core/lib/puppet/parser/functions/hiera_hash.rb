require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera_hash, :type => :rvalue, :arity => -2, :doc => 
  "Returns a merged hash of matches from throughout the hierarchy. In cases where two or 
  more hashes share keys, the hierarchy  order determines which key/value pair will be 
  used in the returned hash, with the pair in the highest priority data source winning.
  
  In addition to the required `key` argument, `hiera_hash` accepts two additional 
  arguments:
  
  - a `default` argument in the second position, providing a  hash to be returned in the 
  absence of any matches for the `key` argument
  - an `override` argument in the third position, providing  a data source to insert at 
  the top of the hierarchy, even if it would not ordinarily match during a Hiera data 
  source lookup. If Hiera doesn't find a match in the named override data source, it will 
  continue to search through the rest of the hierarchy.
    
  `hiera_hash` expects that all values returned will be hashes. If any of the values 
  found in the data sources are strings or arrays, puppet will raise a type mismatch error.

  More thorough examples of `hiera_hash` are available at:  
  <http://docs.puppetlabs.com/hiera/1/puppet.html#hiera-lookup-functions>
  ") do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :hash)
  end
end

