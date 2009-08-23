require 'puppet/file_serving/mount'

# Find files in the modules' plugins directories.
# This is a very strange mount because it merges
# many directories into one.
class Puppet::FileServing::Mount::Plugins < Puppet::FileServing::Mount
    # Return an instance of the appropriate class.
    def find(relative_path, request)
        return nil unless mod = request.environment.modules.find { |mod|  mod.plugin(relative_path) }

        path = mod.plugin(relative_path)

        return path
    end

    def search(relative_path, request)
        # We currently only support one kind of search on plugins - return
        # them all.
        paths = request.environment.modules.find_all { |mod| mod.plugins? }.collect { |mod| mod.plugin_directory }
        return nil if paths.empty?
        return paths
    end

    def valid?
        true
    end
end
