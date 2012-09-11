module Puppet::Parser::Functions
  newfunction(:hiera_hash, :type => :rvalue) do |*args|
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :hash)
  end
end

