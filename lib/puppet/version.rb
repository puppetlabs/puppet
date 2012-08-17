# The version method and constant are isolated in puppet/version.rb so that a
# simple `require 'puppet/version'` allows a rubygems gemspec or bundler
# Gemfile to get the Puppet version of the gem install.
module Puppet
  PUPPETVERSION = '2.7.19'

  def Puppet.version
    PUPPETVERSION
  end
end
