class Puppet::FileSystem::File19 < Puppet::FileSystem::File
  def binread
    @path.binread
  end
end
