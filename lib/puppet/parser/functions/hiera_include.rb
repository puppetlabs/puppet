module Puppet::Parser::Functions
  newfunction(:hiera_include) do |*args|
    if args[0].is_a?(Array)
      args = args[0]
    end

    if args.empty?
      raise(Puppet::ParseError, "Please supply a parameter to perform a Hiera lookup")
    end

    key      = args[0]
    default  = args[1]
    override = args[2]

    require 'hiera'

    hiera_config = Puppet.settings[:hiera_config]
    config = {}

    if File.exist?(hiera_config)
      config = Hiera::Config.load(hiera_config)
    end

    config[:logger] = 'puppet'
    config

    hiera = Hiera.new(:config => config)

    hiera_scope = self

    answer = hiera.lookup(key, default, hiera_scope, override, :array)

    if answer.nil?
      raise(Puppet::ParseError, "Could not find data item #{key} in any Hiera data file and no default supplied")
    end

    method = Puppet::Parser::Functions.function(:include)
    send(method, answer)
  end
end

