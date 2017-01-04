require 'puppet/provider/package'

Puppet::Type.type(:package).provide :puppet_gem, :parent => :gem do
  desc "Puppet Ruby Gem support. This provider is useful for managing
        gems needed by the ruby provided in the puppet-agent package."

  has_feature :versionable, :install_options, :uninstall_options

  if Puppet.features.microsoft_windows?
    puppet_ruby_dir = Puppet::Util.get_env('RUBY_DIR')
    puppet_gem_command = File.expand_path(File.join(puppet_ruby_dir, 'bin', 'gem.bat'))
    commands :gemcmd => puppet_gem_command
  else
    commands :gemcmd => "/opt/puppetlabs/puppet/bin/gem"
  end
end
