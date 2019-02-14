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
end
