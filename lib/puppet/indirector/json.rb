require 'puppet/indirector/terminus'
require 'puppet/util/file_locking'

# The base class for JSON indirection terminus implementations.
#
# This should generally be preferred to the YAML base for any future
# implementations, since it is ~ three times faster despite being pure Ruby
# rather than a C implementation.
class Puppet::Indirector::JSON < Puppet::Indirector::Terminus
  include Puppet::Util::FileLocking

  def find(request)
    load_json_from_file(path(request.key), request.key)
  end

  def save(request)
    filename = path(request.key)
    FileUtils.mkdir_p(File.dirname(filename))
    writelock(filename, 0660) {|f| f.print to_json(request.instance) }
  rescue TypeError => detail
    Puppet.err "Could not save #{self.name} #{request.key}: #{detail}"
  end

  def destroy(request)
    File.unlink(path(request.key))
  rescue => detail
    unless detail.is_a? Errno::ENOENT
      raise Puppet::Error, "Could not destroy #{self.name} #{request.key}: #{detail}"
    end
    1                           # emulate success...
  end

  def search(request)
    Dir.glob(path(request.key)).collect do |file|
      load_json_from_file(file, request.key)
    end
  end

  # Return the path to a given node's file.
  def path(name, ext = '.json')
    if name =~ Puppet::Indirector::BadNameRegexp then
      Puppet.crit("directory traversal detected in #{self.class}: #{name.inspect}")
      raise ArgumentError, "invalid key"
    end

    base = Puppet.run_mode.master? ? Puppet[:server_datadir] : Puppet[:client_datadir]
    File.join(base, self.class.indirection_name.to_s, name.to_s + ext)
  end

  private

  def load_json_from_file(file, key)
    json = nil

    begin
      readlock(file) {|fh| json = fh.read }
    rescue => detail
      return nil unless FileTest.exist?(file)
      raise Puppet::Error, "Could not read JSON data for #{indirection.name} #{key}: #{detail}"
    end

    begin
      return from_json(json)
    rescue => detail
      raise Puppet::Error, "Could not parse JSON data for #{indirection.name} #{key}: #{detail}"
    end
  end

  def from_json(text)
    model.convert_from('pson', text)
  end

  def to_json(object)
    object.render('pson')
  end
end
