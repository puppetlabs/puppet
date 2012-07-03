require 'puppet/indirector/terminus'

class Puppet::Indirector::Hiera < Puppet::Indirector::Terminus
  def initialize(*args)
    if ! Puppet.features.hiera?
      raise "Hiera terminus not supported without hiera library"
    end
    super
  end

  def find(request)
    fake_scope = FakeScope.new(request.options[:facts])
    hiera.lookup(request.key, nil, fake_scope, nil, nil)
  end

  private

  def self.hiera_config
    hiera_config = Puppet.settings[:hiera_config]
    config = {}

    if File.exist?(hiera_config)
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

  # A class that acts just enough like a Puppet::Parser::Scope to
  # fool Hiera's puppet backend. This class doesn't actually do anything
  # but it does allow people to use the puppet backend with the hiera
  # data bindings withough causing problems.
  class FakeScope
    FAKE_RESOURCE = Struct.new(:name).new("fake").freeze
    FAKE_CATALOG = Struct.new(:classes).new([].freeze).freeze

    def initialize(variable_bindings)
      @variable_bindings = variable_bindings
    end

    def [](name)
      @variable_bindings[name]
    end

    def resource
      FAKE_RESOURCE
    end

    def catalog
      FAKE_CATALOG
    end

    def function_include(name)
      # noop
    end
  end
end

