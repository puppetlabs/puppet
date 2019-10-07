require 'puppet/file_serving/mount'

# This is the modules-specific mount: it knows how to search through
# modules for files.  Yay.
class Puppet::FileServing::Mount::Modules < Puppet::FileServing::Mount
  # Return an instance of the appropriate class.
  def find(path, request)
    raise _("No module specified") if path.to_s.empty?
    module_name, relative_path = path.split("/", 2)
    mod = request.environment.module(module_name)
    return nil unless mod

    mod.file(relative_path)
  end

  def search(path, request)
    result = find(path, request)
    if result
      [result]
    end
  end

  def valid?
    true
  end
end
