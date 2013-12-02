class Puppet::Settings::DirectorySetting < Puppet::Settings::FileSetting
  def type
    :directory
  end

  # @api private
  def open_file(filename, option = 'r', &block)
    file = Puppet::FileSystem::File.new(filename)
    controlled_access do |mode|
      file.open(mode, option, &block)
    end
  end
end
