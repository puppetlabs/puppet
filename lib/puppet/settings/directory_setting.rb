class Puppet::Settings::DirectorySetting < Puppet::Settings::FileSetting
  def type
    :directory
  end

  # @api private
  #
  # @param option [String] Extra file operation mode information to use
  #   (defaults to read-only mode 'r')
  #   This is the standard mechanism Ruby uses in the IO class, and therefore
  #   encoding may be explicitly like fmode : encoding or fmode : "BOM|UTF-*"
  #   for example, a:ASCII or w+:UTF-8
  def open_file(filename, option = 'r', &block)
    controlled_access do |mode|
      Puppet::FileSystem.open(filename, mode, option, &block)
    end
  end
end
