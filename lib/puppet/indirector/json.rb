require 'puppet/indirector/terminus'
require 'puppet/util'

# The base class for JSON indirection terminus implementations.
#
# This should generally be preferred to the YAML base for any future
# implementations, since it is faster and can load untrusted data safely.
class Puppet::Indirector::JSON < Puppet::Indirector::Terminus
  def find(request)
    load_json_from_file(path(request.key), request.key)
  end

  def save(request)
    filename = path(request.key)
    FileUtils.mkdir_p(File.dirname(filename))

    Puppet::Util.replace_file(filename, 0660) {|f| f.print to_json(request.instance).force_encoding(Encoding::BINARY) }
  rescue TypeError => detail
    Puppet.log_exception(detail, _("Could not save %{json} %{request}: %{detail}") % { json: self.name, request: request.key, detail: detail })
  end

  def destroy(request)
    Puppet::FileSystem.unlink(path(request.key))
  rescue => detail
    unless detail.is_a? Errno::ENOENT
      raise Puppet::Error, _("Could not destroy %{json} %{request}: %{detail}") % { json: self.name, request: request.key, detail: detail }, detail.backtrace
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
      Puppet.crit(_("directory traversal detected in %{json}: %{name}") % { json: self.class, name: name.inspect })
      raise ArgumentError, _("invalid key")
    end

    base = Puppet.run_mode.master? ? Puppet[:server_datadir] : Puppet[:client_datadir]
    File.join(base, self.class.indirection_name.to_s, name.to_s + ext)
  end

  private

  def load_json_from_file(file, key)
    json = nil

    begin
      json = Puppet::FileSystem.read(file, :encoding => Encoding::BINARY)
    rescue Errno::ENOENT
      return nil
    rescue => detail
      raise Puppet::Error, _("Could not read JSON data for %{name} %{key}: %{detail}") % { name: indirection.name, key: key, detail: detail }, detail.backtrace
    end

    begin
      return from_json(json)
    rescue => detail
      raise Puppet::Error, _("Could not parse JSON data for %{name} %{key}: %{detail}") % { name: indirection.name, key: key, detail: detail }, detail.backtrace
    end
  end

  def from_json(text)
    model.convert_from('json', text.force_encoding(Encoding::UTF_8))
  end

  def to_json(object)
    object.render('json')
  end
end
