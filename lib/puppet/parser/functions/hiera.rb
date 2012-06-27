module Puppet::Parser::Functions
  newfunction(:hiera, :type => :rvalue) do |*args|
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :priority)
  end
end

