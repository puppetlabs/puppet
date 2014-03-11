class Puppet::FileSystem::File18 < Puppet::FileSystem::FileImpl
  def binread(path)
    ::File.open(path, 'rb') { |f| f.read }
  end
end
