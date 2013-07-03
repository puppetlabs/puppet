require 'puppet/indirector/terminus'

class Puppet::Indirector::Hiera < Puppet::Indirector::Terminus
  def initialize(*args)
    if ! Puppet.features.hiera?
      raise "Hiera terminus not supported without hiera library"
    end
    super
  end

  def find(request)
    hiera.lookup(request.key, nil, request.options[:variables], nil, nil)
  end

  private

  def self.hiera_config
    hiera_config = Puppet.settings[:hiera_config]
    config = {}

    if hiera_config.is_a?(Hash) or hiera_config.is_a?(String)
      if hiera_config.is_a?(String) and not File.exist?(hiera_config)
        Puppet.warning "Config file #{hiera_config} not found, using Hiera defaults"
      else
        config = Hiera::Config.load(hiera_config)
      end
    end

    config[:logger] = 'puppet'
    config
  end

  def self.hiera
    @hiera ||= Hiera.new(:config => hiera_config)
  end

  def hiera
    self.class.hiera
  end
end

