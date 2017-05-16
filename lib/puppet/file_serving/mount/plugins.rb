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

end
