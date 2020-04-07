Puppet::Type.type(:package).provide :puppet_gem, :parent => :gem do
  desc "Puppet Ruby Gem support. This provider is useful for managing
        gems needed by the ruby provided in the puppet-agent package."

  has_feature :versionable, :install_options, :uninstall_options

  if Puppet::Util::Platform.windows?
    # On windows, we put our ruby ahead of anything that already
    # existed on the system PATH. This means that we do not need to
    # sort out the absolute path.
    commands :gemcmd => "gem"
  else
    commands :gemcmd => "/opt/puppetlabs/puppet/bin/gem"
  end

  def uninstall
    super
    Puppet.debug("Invalidating rubygems cache after uninstalling gem '#{resource[:name]}'")
    Puppet::Util::Autoload.gem_source.clear_paths
  end
end
