require 'puppet/indirector/terminus'
require 'hiera/scope'

class Puppet::Indirector::Hiera < Puppet::Indirector::Terminus
  def initialize(*args)
    if ! Puppet.features.hiera?
      raise "Hiera terminus not supported without hiera library"
    end
    super
  end

  if defined?(::Psych::SyntaxError)
    DataBindingExceptions = [::StandardError, ::Psych::SyntaxError]
  else
    DataBindingExceptions = [::StandardError]
  end

  def find(request)
    # TODO: Passing a special 'not_found' object to Hiera doesn't really help us distinguish between a not found
    # and a matching key with a nil value because Hiera will produce the default value in both cases. But this
    # opens up for a future improvement of Hiera.
    #
    not_found = Object.new
    value = hiera.lookup(request.key, not_found, Hiera::Scope.new(request.options[:variables]), nil, nil)
    throw :no_such_key if value.equal?(not_found)
    value
  rescue *DataBindingExceptions => detail
    raise Puppet::DataBinding::LookupError.new(detail.message, detail)
  end

  private

  def self.hiera_config
    hiera_config = Puppet.settings[:hiera_config]
    config = {}

    if Puppet::FileSystem.exist?(hiera_config)
      config = Hiera::Config.load(hiera_config)
    else
      Puppet.warning "Config file #{hiera_config} not found, using Hiera defaults"
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

