require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:msi, :parent => Puppet::Provider::Package) do
  desc "Package management by installing and removing MSIs."

  confine    :operatingsystem => :windows
  defaultfor :operatingsystem => :windows

  has_feature :install_options

  # This is just here to make sure we can find it, and fail if we
  # can't.  Unfortunately, we need to do "special" quoting of the
  # install options or msiexec.exe won't know what to do with them, if
  # the value contains a space.
  commands :msiexec => "msiexec.exe"

  def self.instances
    Dir.entries(installed_listing_dir).reject {|d| d == '.' or d == '..'}.collect do |name|
      new(:name => File.basename(name, '.yml'), :provider => :msi, :ensure => :installed)
    end
  end

  def query
    {:name => resource[:name], :ensure => :installed} if FileTest.exists?(state_file)
  end

  def install
    properties_for_command = nil
    if resource[:install_options]
      properties_for_command = resource[:install_options].collect do |k,v|
        property = shell_quote k
        value    = shell_quote v

        "#{property}=#{value}"
      end
    end

    # Unfortunately, we can't use the msiexec method defined earlier,
    # because of the special quoting we need to do around the MSI
    # properties to use.
    execute ['msiexec.exe', '/qn', '/norestart', '/i', shell_quote(msi_source), properties_for_command].flatten.compact.join(' ')

    File.open(state_file, 'w') do |f|
      metadata = {
        'name'            => resource[:name],
        'install_options' => resource[:install_options],
        'source'          => msi_source
      }

      f.puts(YAML.dump(metadata))
    end
  end

  def uninstall
    msiexec '/qn', '/norestart', '/x', msi_source

    File.delete state_file
  end

  def validate_source(value)
    fail("The source parameter cannot be empty when using the MSI provider.") if value.empty?
  end

  private

  def msi_source
    resource[:source] ||= YAML.load_file(state_file)['source'] rescue nil

    fail("The source parameter is required when using the MSI provider.") unless resource[:source]

    resource[:source]
  end

  def self.installed_listing_dir
    listing_dir = File.join(Puppet[:vardir], 'db', 'package', 'msi')

    FileUtils.mkdir_p listing_dir unless File.directory? listing_dir

    listing_dir
  end

  def state_file
    File.join(self.class.installed_listing_dir, "#{resource[:name]}.yml")
  end

  def shell_quote(value)
    value.include?(' ') ? %Q["#{value.gsub(/"/, '\"')}"] : value
  end
end
