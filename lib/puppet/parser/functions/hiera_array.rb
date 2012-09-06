require 'hiera_puppet'

module Puppet::Parser::Functions
  newfunction(:hiera_array, :type => :rvalue) do |*args|
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :array)
  end
end

