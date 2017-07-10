require 'puppet/network/authstore'
require 'puppet/util/logging'
require 'puppet/file_serving'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/content'

# Broker access to the filesystem, converting local URIs into metadata
# or content objects.
class Puppet::FileServing::Mount < Puppet::Network::AuthStore
  include Puppet::Util::Logging

  attr_reader :name

  def find(path, options)
    raise NotImplementedError
  end

  # Create our object.  It must have a name.
  def initialize(name)
    unless name =~ %r{^[-\w]+$}
      raise ArgumentError, _("Invalid mount name format '%{name}'") % { name: name }
    end
    @name = name

    super()
  end

  def search(path, options)
    raise NotImplementedError
  end

  def to_s
    "mount[#{@name}]"
  end

  # A noop.
  def validate
  end

  def find_node_whitelist(request)
    begin
      node = Puppet::Node.indirection.find(request.node, :environment => request.environment)
    rescue => detail
      message = "Failed when searching for node during pluginsync #{request.node}: #{detail}"
      Puppet.log_exception(detail, message)
      raise Puppet::Error, message
    end

    node.parameters['::fqdn'] = node.parameters['fqdn'] if node.parameters.include? 'fqdn'
    node.parameters['::foreman_env'] = node.parameters['foreman_env'] if node.parameters.include? 'foreman_env'
    if node.parameters.include? 'hostgroup'
      hostgroups = node.parameters['hostgroup'].split('/')
      hostgroups.each_index { |idx|
        node.parameters["::encgroup_#{idx}"] = hostgroups[idx]
      }
    end
    hiera = Hiera.new(:config => hiera_config)
    enable = hiera.lookup(Puppet.settings[:pluginsync_filter_client_enable_key], nil, node.parameters, nil, nil)
    whitelist = nil
    if not enable.nil? and enable == true
        whitelist = hiera.lookup(Puppet.settings[:pluginsync_filter_client_whitelist_key], nil, node.parameters, nil, :array)
    end
  end

  def hiera_config
    hiera_config = Puppet.settings[:hiera_config]
    config = {}

    if ::File.exist?(hiera_config)
      config = Hiera::Config.load(hiera_config)
    else
      Puppet.warning "Config file #{hiera_config} not found, using Hiera defaults"
    end

    config[:logger] = 'puppet'
    config
  end
end
