require 'puppet/provider/package'

Puppet::Type.type(:package).provide :puppet_gem, :parent => :gem do
  desc "Puppet Ruby Gem support. This provider is useful for managing
        gems needed by the ruby provided in the puppet-agent package."

  has_feature :versionable, :install_options

  commands :gemcmd => "/opt/puppetlabs/puppet/bin/gem"
end
