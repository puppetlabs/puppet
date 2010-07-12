require 'puppet/indirector/terminus'

# Store instances as files, usually serialized using some format.
class Puppet::Indirector::File < Puppet::Indirector::Terminus
  # Where do we store our data?
  def data_directory
    name = Puppet.run_mode.master? ? :server_datadir : :client_datadir

    File.join(Puppet.settings[name], self.class.indirection_name.to_s)
  end

  def file_format(path)
    path =~ /\.(\w+)$/ and return $1
  end

  def file_path(request)
    File.join(data_directory, request.key + ".#{serialization_format}")
  end

  def latest_path(request)
    files = Dir.glob(File.join(data_directory, request.key + ".*"))
    return nil if files.empty?

    # Return the newest file.
    files.sort { |a, b| File.stat(b).mtime <=> File.stat(a).mtime }[0]
  end

  def serialization_format
    model.default_format
  end

  # Remove files on disk.
  def destroy(request)
    begin
      removed = false
      Dir.glob(File.join(data_directory, request.key.to_s + ".*")).each do |file|
        removed = true
        File.unlink(file)
      end
    rescue => detail
      raise Puppet::Error, "Could not remove #{request.key}: #{detail}"
    end

    raise Puppet::Error, "Could not find files for #{request.key} to remove" unless removed
  end

  # Return a model instance for a given file on disk.
  def find(request)
    return nil unless path = latest_path(request)
    format = file_format(path)

    raise ArgumentError, "File format #{format} is not supported by #{self.class.indirection_name}" unless model.support_format?(format)

    begin
      return model.convert_from(format, File.read(path))
    rescue => detail
      raise Puppet::Error, "Could not convert path #{path} into a #{self.class.indirection_name}: #{detail}"
    end
  end

  # Save a new file to disk.
  def save(request)
    path = file_path(request)

    dir = File.dirname(path)

    raise Puppet::Error.new("Cannot save #{request.key}; parent directory #{dir} does not exist") unless File.directory?(dir)

    begin
      File.open(path, "w") { |f| f.print request.instance.render(serialization_format) }
    rescue => detail
      raise Puppet::Error, "Could not write #{request.key}: #{detail}" % [request.key, detail]
    end
  end

  def path(key)
    key
  end
end
