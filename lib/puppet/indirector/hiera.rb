require 'puppet/indirector/terminus'
require 'hiera_puppet'

class Puppet::Indirector::Hiera < Puppet::Indirector::Terminus
  def initialize(*args)
    if ! Puppet.features.hiera?
      raise "Hiera terminus not supported without hiera library"
    end
    super
  end

  def find(request)
    HieraPuppet.lookup(request.key, nil, request.options[:variables], nil, nil)
  end
end

