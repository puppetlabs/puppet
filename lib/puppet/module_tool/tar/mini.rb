class Puppet::ModuleTool::Tar::Mini
  def initialize(module_name)
    @module_name = module_name
  end

  def unpack(sourcefile, destdir)
    Zlib::GzipReader.open(sourcefile) do |reader|
      Archive::Tar::Minitar.unpack(reader, destdir) do |action, name, stats|
        case action
        when :dir, :file_start
          validate_entry(destdir, name)
          Puppet.debug("extracting #{destdir}/#{name}")
        end
      end
    end
  end

  def pack(sourcedir, destfile)
    Zlib::GzipWriter.open(destfile) do |writer|
      Archive::Tar::Minitar.pack(sourcedir, writer)
    end
  end

  private

  def validate_entry(destdir, path)
    if Pathname.new(path).absolute?
      raise Puppet::ModuleTool::Errors::InvalidPathInPackageError,
        :requested_package => @module_name, :entry_path => path, :directory => destdir
    end

    path = File.expand_path File.join(destdir, path)

    if path !~ /\A#{Regexp.escape destdir}/
      raise Puppet::ModuleTool::Errors::InvalidPathInPackageError,
        :requested_package => @module_name, :entry_path => path, :directory => destdir
    end
  end
end
