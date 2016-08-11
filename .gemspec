# -*- encoding: utf-8 -*-
#
# PLEASE NOTE
# This gemspec is not intended to be used for building the Puppet gem.  This
# gemspec is intended for use with bundler when Puppet is a dependency of
# another project.  For example, the stdlib project is able to integrate with
# the master branch of Puppet by using a Gemfile path of
# git://github.com/puppetlabs/puppet.git
#
# Please see the [packaging
# repository](https://github.com/puppetlabs/packaging) for information on how
# to build the Puppet gem package.

$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))
require 'puppet/version'

Gem::Specification.new do |s|
  s.name = "puppet"
  version = Puppet.version
  mdata = version.match(/(\d+\.\d+\.\d+)/)
  s.version = mdata ? mdata[1] : version

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1")
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")
  s.authors = ["Puppet Labs"]
  s.date = "2012-08-17"
  s.description = "Puppet, an automated configuration management tool"
  s.email = "puppet@puppetlabs.com"
  s.executables = ["puppet"]
  s.files = ["bin/puppet"]
  s.homepage = "https://puppetlabs.com"
  s.rdoc_options = ["--title", "Puppet - Configuration Management", "--main", "README", "--line-numbers"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "puppet"
  s.summary = "Puppet, an automated configuration management tool"
  s.specification_version = 3
  s.add_runtime_dependency(%q<facter>, [">= 2.0.1", "< 4"])
  s.add_runtime_dependency(%q<hiera>, [">= 2.0", "< 4"])
end
