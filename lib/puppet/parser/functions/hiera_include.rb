module Puppet::Parser::Functions
  newfunction(:hiera_include, :arity => -2) do |*args|
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)
    if answer = HieraPuppet.lookup(key, default, self, override, :array)
      method = Puppet::Parser::Functions.function(:include)
      send(method, answer)
    else
      raise Puppet::ParseError, "Could not find data item #{key}"
    end
  end
end

