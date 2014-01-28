require 'puppet/file_serving/mount'
require 'hiera'

# Find files in the modules' plugins directories.
# This is a very strange mount because it merges
# many directories into one.
class Puppet::FileServing::Mount::Plugins < Puppet::FileServing::Mount
  # Return an instance of the appropriate class.
  def find(relative_path, request)
    return nil unless mod = request.environment.modules.find { |m|  m.plugin(relative_path) }

    path = mod.plugin(relative_path)

    path
  end

  def search(relative_path, request)
    # We currently only support one kind of search on plugins - return
    # them all.
    Puppet.debug("Warning: calling Plugins.search with empty module path.") if request.environment.modules.empty?

    modules = request.environment.modules.find_all { |mod| mod.plugins? }

    whitelist = find_node_whitelist(request) if Puppet.settings[:pluginsync_filter_enable]

    if whitelist
        Puppet.debug "Modules to be pluginsynced: #{whitelist.inspect}"
        modules = modules.select { |mod| whitelist.include? mod.name }
    else
        Puppet.debug "Pluginsync filter not enabled or not found, all modules will be included"
    end
    paths = modules.collect { |mod| mod.plugin_directory }

    if paths.empty?
      # If the modulepath is valid then we still need to return a valid root
      # directory for the search, but make sure nothing inside it is
      # returned.
      request.options[:recurse] = false
      request.environment.modulepath.empty? ? nil : request.environment.modulepath
    else
      paths
    end
  end

  def valid?
    true
  end

  private

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
