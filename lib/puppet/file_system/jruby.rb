require 'puppet/file_system/posix'

class Puppet::FileSystem::JRuby < Puppet::FileSystem::Posix
  def unlink(*paths)
    File.unlink(*paths)
  rescue Errno::ENOENT
    # JRuby raises ENOENT if the path doesn't exist or the parent directory
    # doesn't allow execute/traverse. If it's the former, `stat` will raise
    # ENOENT, if it's the later, it'll raise EACCES
    # See https://github.com/jruby/jruby/issues/5617
    stat(*paths)
  end

  def replace_file(path, mode = nil, &block)
    # MRI Ruby rename checks if destination is a directory and raises, while
    # JRuby removes the directory and replaces the file.
    if Puppet::FileSystem.directory?(path)
      raise Errno::EISDIR, _("Is a directory: %{directory}") % { directory: path }
    end

    super
  end
end
