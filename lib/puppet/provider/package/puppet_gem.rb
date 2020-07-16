require 'puppet/provider/package/gem'

Puppet::Type.type(:package).provide :puppet_gem, :parent => :gem do
  desc "Puppet Ruby Gem support. This provider is useful for managing
        gems needed by the ruby provided in the puppet-agent package."

  has_feature :versionable, :install_options, :uninstall_options

  if Puppet.features.microsoft_windows?
    # On windows, we put our ruby ahead of anything that already
    # existed on the system PATH. This means that we do not need to
    # sort out the absolute path.
    commands :gemcmd => "gem"
  else
    commands :gemcmd => "/opt/puppetlabs/puppet/bin/gem"
  end

  def self.execute_gem_command(command, command_options, custom_environment = {})
    custom_environment['PKG_CONFIG_PATH'] = '/opt/puppetlabs/puppet/lib/pkgconfig' unless Puppet::Util::Platform.windows?
    super(command, command_options, custom_environment)
  end
end
