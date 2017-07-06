require 'puppet/indirector/terminus'
require 'puppet/util'

# The base class for MessagePack indirection terminus implementations.
#
# This should generally be preferred to the PSON base for any future
# implementations, since it is ~ 30 times faster
class Puppet::Indirector::Msgpack < Puppet::Indirector::Terminus
  def initialize(*args)
    if ! Puppet.features.msgpack?
      raise "MessagePack terminus not supported without msgpack library"
    end
    super
  end

  def find(request)
    load_msgpack_from_file(path(request.key), request.key)
  end

  def save(request)
    filename = path(request.key)
    FileUtils.mkdir_p(File.dirname(filename))

    Puppet::Util.replace_file(filename, 0660) {|f| f.print to_msgpack(request.instance) }
  rescue TypeError => detail
    Puppet.log_exception(detail, "Could not save #{self.name} #{request.key}: #{detail}")
  end

  def destroy(request)
    Puppet::FileSystem.unlink(path(request.key))
  rescue => detail
    unless detail.is_a? Errno::ENOENT
      raise Puppet::Error, "Could not destroy #{self.name} #{request.key}: #{detail}", detail.backtrace
    end
    1                           # emulate success...
  end

  def search(request)
    Dir.glob(path(request.key)).collect do |file|
      load_msgpack_from_file(file, request.key)
    end
  end

  # Return the path to a given node's file.
  def path(name, ext = '.msgpack')
    if name =~ Puppet::Indirector::BadNameRegexp then
      Puppet.crit("directory traversal detected in #{self.class}: #{name.inspect}")
      raise ArgumentError, "invalid key"
    end

    base = Puppet.run_mode.master? ? Puppet[:server_datadir] : Puppet[:client_datadir]
    File.join(base, self.class.indirection_name.to_s, name.to_s + ext)
  end

  private

  def load_msgpack_from_file(file, key)
    msgpack = nil

    begin
      msgpack = Puppet::FileSystem.read(file, :encoding => 'utf-8')
    rescue Errno::ENOENT
      return nil
    rescue => detail
      raise Puppet::Error, "Could not read MessagePack data for #{indirection.name} #{key}: #{detail}", detail.backtrace
    end

    begin
      return from_msgpack(msgpack)
    rescue => detail
      raise Puppet::Error, "Could not parse MessagePack data for #{indirection.name} #{key}: #{detail}", detail.backtrace
    end
  end

  def from_msgpack(text)
    model.convert_from('msgpack', text)
  end

  def to_msgpack(object)
    object.render('msgpack')
  end
end
