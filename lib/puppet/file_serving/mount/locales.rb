require 'puppet/file_serving/mount'

# Find files in the modules' locales directories.
# This is a very strange mount because it merges
# many directories into one.
class Puppet::FileServing::Mount::Locales < Puppet::FileServing::Mount
  # Return an instance of the appropriate class.
  def find(relative_path, request)
    return nil unless mod = request.environment.modules.find { |m|  m.locale(relative_path) }

    path = mod.locale(relative_path)

    path
  end

  def search(relative_path, request)
    # We currently only support one kind of search on locales - return
    # them all.
    Puppet.debug("Warning: calling Locales.search with empty module path.") if request.environment.modules.empty?
    paths = request.environment.modules.find_all { |mod| mod.locales? }.collect { |mod| mod.locale_directory }
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
