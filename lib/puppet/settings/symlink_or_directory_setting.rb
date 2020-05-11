class Puppet::Settings::SymlinkOrDirectorySetting < Puppet::Settings::DirectorySetting

  def initialize(args)
    super
  end

  def type
    if Puppet::FileSystem.symlink?(self.value)
      :symlink
    else
      :directory
    end
  end
end
