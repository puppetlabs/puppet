# The version method and constant are isolated in puppet/version.rb so that a
# simple `require 'puppet/version'` allows a rubygems gemspec or bundler
# Gemfile to get the Puppet version of the gem install.
#
# The version is programatically settable because we want to allow the
# Raketasks and such to set the version based on the output of `git describe`
#
module Puppet
  version = 'DEVELOPMENT'
  if version == 'DEVELOPMENT'
    %x{git rev-parse --is-inside-work-tree > /dev/null 2>&1}
    if $?.success?
      version = %x{git describe --tags --always 2>&1}.chomp
    end
  end

  if not defined? PUPPETVERSION
    PUPPETVERSION = version
  end

  def self.version
    @puppet_version || PUPPETVERSION
  end

  def self.version=(version)
    @puppet_version = version
  end
end
