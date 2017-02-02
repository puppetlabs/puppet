class Puppet::Settings::FileOrDirectorySetting < Puppet::Settings::FileSetting

  def initialize(args)
    super
  end

  def type
    if Puppet::FileSystem.directory?(self.value) || @path_ends_with_slash
      :directory
    else
      :file
    end
  end

  # Overrides munge to be able to read the un-munged value (the FileSetting.munch removes trailing slash)
  #
  def munge(value)
    if value.is_a?(String) && value =~ /[\\\/]$/
      @path_ends_with_slash = true
    end
    super
  end

  # @api private
  #
  # @param option [String] Extra file operation mode information to use
  #   (defaults to read-only mode 'r')
  #   This is the standard mechanism Ruby uses in the IO class, and therefore
  #   encoding may be explicitly like fmode : encoding or fmode : "BOM|UTF-*"
  #   for example, a:ASCII or w+:UTF-8
  def open_file(filename, option = 'r', &block)
    if type == :file
      super
    else
      controlled_access do |mode|
        Puppet::FileSystem.open(filename, mode, option, &block)
      end
    end
  end
end
