require 'puppet/file_serving/mount'

# This is the modules-specific mount: it knows how to search through
# modules for files.  Yay.
class Puppet::FileServing::Mount::Modules < Puppet::FileServing::Mount
  # Return an instance of the appropriate class.
  def find(path, request)
    raise "No module specified" if path.to_s.empty?
    module_name, relative_path = path.split("/", 2)
    return nil unless mod = request.environment.module(module_name)

    mod.file(relative_path)
  end

  def search(path, request)
    if result = find(path, request)
      [result]
    end
  end

  def valid?
    true
  end
end
