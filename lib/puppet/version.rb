# The version method and constant are isolated in puppet/version.rb so that a
# simple `require 'puppet/version'` allows a rubygems gemspec or bundler
# Gemfile to get the Puppet version of the gem install.
#
# The version is programatically settable because we want to allow the
# Raketasks and such to set the version based on the output of `git describe`
#
module Puppet
  PUPPETVERSION = '2.7.20'

  def self.version
    @puppet_version || PUPPETVERSION
  end

  def self.version=(version)
    @puppet_version = version
  end
end
