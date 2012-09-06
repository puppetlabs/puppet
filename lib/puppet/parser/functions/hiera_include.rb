module Puppet::Parser::Functions
  newfunction(:hiera_include) do |*args|
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)
    answer = HieraPuppet.lookup(key, default, self, override, :array)

    method = Puppet::Parser::Functions.function(:include)
    send(method, answer)
  end
end

