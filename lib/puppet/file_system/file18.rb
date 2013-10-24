class Puppet::FileSystem::File18 < Puppet::FileSystem::File
  def binread
    ::File.open(@path, 'rb') { |f| f.read }
  end
end
