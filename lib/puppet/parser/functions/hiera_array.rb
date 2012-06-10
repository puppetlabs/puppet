module Puppet::Parser::Functions
  newfunction(:hiera_array, :type => :rvalue) do |*args|
    if args[0].is_a?(Array)
      args = args[0]
    end

    if args.empty?
      raise(Puppet::ParseError, "Please supply a parameter to perform a Hiera lookup")
    end

    key      = args[0]
    default  = args[1]
    override = args[2]

    configfile = File.join([File.dirname(Puppet.settings[:config]), "hiera.yaml"])

    unless File.exist?(configfile)
      raise(Puppet::ParseError, "Hiera config file #{configfile} not readable")
    end

    require 'hiera'

    config = YAML.load_file(configfile)
    config[:logger] = "puppet"

    hiera = Hiera.new(:config => config)

    hiera_scope = self

    answer = hiera.lookup(key, default, hiera_scope, override, :array)

    if answer.nil?
      raise(Puppet::ParseError, "Could not find data item #{key} in any Hiera data file and no default supplied")
    end

    answer
  end
end

