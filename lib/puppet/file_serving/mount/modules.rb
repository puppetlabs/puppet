require 'puppet/file_serving/mount'

# This is the modules-specific mount: it knows how to search through
# modules for files.  Yay.
class Puppet::FileServing::Mount::Modules < Puppet::FileServing::Mount
    # Return an instance of the appropriate class.
    def find(path, request)
        module_name, relative_path = path.split("/", 2)
        return nil unless mod = request.environment.module(module_name)

        mod.file(relative_path)
    end

    def search(path, request)
        module_name, relative_path = path.split("/", 2)
        return nil unless mod = request.environment.module(module_name)

        return nil unless path = mod.file(relative_path)
        return [path]
    end

    def valid?
        true
    end
end
