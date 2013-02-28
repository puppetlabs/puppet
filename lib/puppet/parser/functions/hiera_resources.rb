module Puppet::Parser::Functions
#  newfunction(:hiera_resources, :type => :statement, :arity => -2) do |args|
  newfunction(:hiera_resources, :arity => -2) do |args|
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)
    if answer = HieraPuppet.lookup(key, default, self, override, :hash)
      answer.each do |res_type, res_params|
        method = Puppet::Parser::Functions.function(:create_resources)
        send(res_type, res_params)
      end
    else
      raise Puppet::ParseError, "Could not find data item #{key}"
    end
  end
end
