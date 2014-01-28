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

    if node.parameters.include? 'hostgroup'
      hostgroups = node.parameters['hostgroup'].split('/')
      hostgroups.each_index { |idx|
        node.parameters["encgroup_#{idx}"] = hostgroups[idx]
      }
    end

    def generate_scope(node)
      compiler = Puppet::Parser::Compiler.new(node)
      node.parameters.each do |param, value|
        compiler.topscope[param.to_s] = value.is_a?(Symbol) ? value.to_s : value
      end
      yield compiler.topscope
    end

    whitelist = nil
    generate_scope(node) do |scope|
      lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope)
      loaders = Puppet::Pops::Loaders.new(node.environment)
      Puppet.override( {:loaders => loaders } , 'For the pluginsync filter') do
        enable = Puppet::Pops::Lookup.lookup(Puppet.settings[:pluginsync_filter_client_enable_key],
                                             Puppet::Pops::Types::TypeFactory.boolean(),
                                             true,
                                             true,
                                             nil,
                                             lookup_invocation)
        if not enable.nil? and enable
            whitelist = Puppet::Pops::Lookup.lookup(Puppet.settings[:pluginsync_filter_client_whitelist_key],
                                                    Puppet::Pops::Types::TypeFactory.iterable(),
                                                    [],
                                                    true,
                                                    'unique',
                                                    lookup_invocation)
        end
      end
    end
    whitelist
  end
end
