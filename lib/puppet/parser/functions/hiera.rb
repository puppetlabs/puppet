module Puppet::Parser::Functions
  newfunction(:hiera, :type => :rvalue) do |*args|
    # Functions called from puppet manifests that look like this:
    #   lookup("foo", "bar")
    # internally in puppet are invoked:  func(["foo", "bar"])
    #
    # where as calling from templates should work like this:
    #   scope.function_lookup("foo", "bar")
    #
    #  Therefore, declare this function with args '*args' to accept any number
    #  of arguments and deal with puppet's special calling mechanism now:
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

    answer = hiera.lookup(key, default, hiera_scope, override, :priority)

    if answer.nil?
      raise(Puppet::ParseError, "Could not find data item #{key} in any Hiera data file and no default supplied")
    end

    return answer
  end
end

