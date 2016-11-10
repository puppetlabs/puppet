class Puppet::Settings::MultiFileSetting < Puppet::Settings::FileSetting

  def initialize(args)
    super
  end

  # Overrides munge to be able to read the un-munged value (the FileSetting.munge removes trailing slash)
  #
  def munge(value)
    if value.is_a?(String)
      value = value.split(File::PATH_SEPARATOR).map { |d| File.expand_path(d) }
    end
    value
  end

  # Turn our setting thing into a Puppet::Resource instance.
  def to_resource
    return nil unless type = self.type

    paths = self.value
    return nil unless paths.is_a?(Array)

    paths.map {|path| create_resource(type, path)}.select {|path| path}
  end

  # @api private
  def exclusive_open(option = 'r', &block)
    controlled_access do |mode|
      value.each do |file|
        Puppet::FileSystem.exclusive_open(file, mode, option, &block)
      end
    end
  end

  # @api private
  def open(option = 'r', &block)
    controlled_access do |mode|
      value.each do |file|
        Puppet::FileSystem.open(file, mode, option, &block)
      end
    end
  end
end
