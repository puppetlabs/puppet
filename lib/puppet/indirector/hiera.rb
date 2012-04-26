require 'puppet/indirector/terminus'

class Puppet::Indirector::Hiera < Puppet::Indirector::Terminus
  def initialize(*args)
    if ! Puppet.features.hiera?
      raise "Hiera terminus not supported without hiera gem"
    end
    super
  end

  def find(request)
    facts = Puppet::Node::Facts.indirection.find(request.options[:host]).values
    hiera.lookup(request.key, nil, facts, nil, nil)
  end

  private

  def self.hiera
    @hiera || Hiera.new(:config => Puppet.settings[:hiera_config])
  end

  def hiera
    self.class.hiera
  end
end

