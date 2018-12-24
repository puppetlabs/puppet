require 'puppet/provider/package'

Puppet::Type.type(:package).provide :puppet_gem, :parent => :gem do
  desc "Puppet Ruby Gem support. This provider is useful for managing
        gems needed by the ruby provided in the puppet-agent package."

  has_feature :versionable, :install_options, :uninstall_options

  # Puppet on Windows prepends its paths to PATH, including Puppet's RUBY_DIR.
  # This means that we do not need to specify the absolute path.
  if Puppet::Util::Platform.windows?
    gem_cmd = 'gem.bat'
  else
    gem_cmd = '/opt/puppetlabs/puppet/bin/gem'
  end

  commands :gemcmd => gem_cmd
end
