class Puppet::Settings::DirectorySetting < Puppet::Settings::FileSetting
  def type
    :directory
  end

  # @api private
  def open_file(filename, option = 'r', &block)
    controlled_access do |mode|
      Puppet::FileSystem.open(filename, mode, option, &block)
    end
  end
end
