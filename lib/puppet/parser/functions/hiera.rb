require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera, :type => :rvalue) do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :priority)
  end
end

