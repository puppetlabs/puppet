require 'puppet/indirector/terminus'
require 'puppet/util/file_locking'

# The base class for MARSHAL indirection termini.
class Puppet::Indirector::Marshal < Puppet::Indirector::Terminus
  include Puppet::Util::FileLocking

  # Read a given name's file in and convert it from YAML.
  def find(request)
    file = path(request.key)
    return nil unless FileTest.exist?(file)

    marshal = nil
    begin
      file = File.open(file, 'r')
    rescue => detail
      raise Puppet::Error, "Could not read MARSHAL data for #{indirection.name} #{request.key}: #{detail}"
    end
    begin
      marshal = from_marshal(file.read)
      file.close
      return marshal
    rescue => detail
      raise Puppet::Error, "Could not parse MARSHAL data for #{indirection.name} #{request.key}: #{detail}"
    end
  end

  # Convert our object to MARSHAL and store it to the disk.
  def save(request)
    raise ArgumentError.new("You can only save objects that respond to :name") unless request.instance.respond_to?(:name)
    file = path(request.key)

    basedir = File.dirname(file)

    # This is quite likely a bad idea, since we're not managing ownership or modes.
    Dir.mkdir(basedir) unless FileTest.exist?(basedir)

    begin
    file = File.new(file,'w')
    file.write to_marshal(request.instance)
    file.close
    rescue TypeError => detail
      Puppet.err "Could not save #{self.name} #{request.key}: #{detail}"
    end
  end

  # Return the path to a given node's file.
  def path(name,ext='.marshal')
    if name =~ Puppet::Indirector::BadNameRegexp then
      Puppet.crit("directory traversal detected in #{self.class}: #{name.inspect}")
      raise ArgumentError, "invalid key"
    end

    base = Puppet.run_mode.master? ? Puppet[:yamldir] : Puppet[:clientyamldir]
    File.join(base, self.class.indirection_name.to_s, name.to_s + ext)
  end

  def search(request)
    Dir.glob(path(request.key,'')).collect do |file|
      file_load = File.open(file, 'r')
      from_marshal(file.read)
      file.close
    end
  end

  private

  def from_marshal(text)
    Marshal.load(text)
  end

  def to_marshal(object)
    Marshal.dump(object)
  end
end
