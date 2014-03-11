require 'puppet/indirector/terminus'
require 'puppet/util/yaml'

# The base class for YAML indirection termini.
class Puppet::Indirector::Yaml < Puppet::Indirector::Terminus
  # Read a given name's file in and convert it from YAML.
  def find(request)
    file = path(request.key)
    return nil unless Puppet::FileSystem.exist?(file)

    begin
      return fix(Puppet::Util::Yaml.load_file(file))
    rescue Puppet::Util::Yaml::YamlLoadError => detail
      raise Puppet::Error, "Could not parse YAML data for #{indirection.name} #{request.key}: #{detail}", detail.backtrace
    end
  end

  # Convert our object to YAML and store it to the disk.
  def save(request)
    raise ArgumentError.new("You can only save objects that respond to :name") unless request.instance.respond_to?(:name)

    file = path(request.key)

    basedir = File.dirname(file)

    # This is quite likely a bad idea, since we're not managing ownership or modes.
    Dir.mkdir(basedir) unless Puppet::FileSystem.exist?(basedir)

    begin
      Puppet::Util::Yaml.dump(request.instance, file)
    rescue TypeError => detail
      Puppet.err "Could not save #{self.name} #{request.key}: #{detail}"
    end
  end

  # Return the path to a given node's file.
  def path(name,ext='.yaml')
    if name =~ Puppet::Indirector::BadNameRegexp then
      Puppet.crit("directory traversal detected in #{self.class}: #{name.inspect}")
      raise ArgumentError, "invalid key"
    end

    base = Puppet.run_mode.master? ? Puppet[:yamldir] : Puppet[:clientyamldir]
    File.join(base, self.class.indirection_name.to_s, name.to_s + ext)
  end

  def destroy(request)
    file_path = path(request.key)
    Puppet::FileSystem.unlink(file_path) if Puppet::FileSystem.exist?(file_path)
  end

  def search(request)
    Dir.glob(path(request.key,'')).collect do |file|
      fix(Puppet::Util::Yaml.load_file(file))
    end
  end

  protected

  def fix(object)
    object
  end
end
