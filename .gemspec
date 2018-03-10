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

Gem::Specification.new do |s|
  s.name = "puppet"
  version = "6.0.0"
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
  s.add_runtime_dependency(%q<hiera>, [">= 3.2.1", "< 4"])
  # PUP-7115 - return to a gem dependency in Puppet 5
  # s.add_runtime_dependency(%q<semantic_puppet>, ['>= 0.1.3', '< 2'])
  # i18n support (gettext-setup and dependencies)
  s.add_runtime_dependency(%q<fast_gettext>, "~> 1.1.2")
  s.add_runtime_dependency(%q<locale>, "~> 2.1")
  # hocon is an optional hiera backend shipped in puppet-agent packages
  s.add_runtime_dependency(%q<hocon>, "~> 1.0")
  # net-ssh is a runtime dependency of Puppet::Util::NetworkDevice::Transport::Ssh
  # Beaker 3.0.0 to 3.10.0 depends on net-ssh 3.3.0beta1
  # Beaker 3.11.0+ depends on net-ssh 4.0+
  # be lenient to allow module testing where Beaker and Puppet are in same Gemfile
  s.add_runtime_dependency(%q<net-ssh>, [">= 3.0", "< 5"]) if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.0.0')

  # loads platform specific gems like ffi, win32 platform gems
  # as additional runtime dependencies
  gem_deps_path = File.join(File.dirname(__FILE__), 'ext', 'project_data.yaml')

  # inside of a Vanagon produced package, project_data.yaml does not exist
  next unless File.exist?(gem_deps_path)

  # so only load these dependencies from a git clone / bundle install workflow
  require 'yaml'
  data = YAML.load_file(gem_deps_path)
  bundle_platforms = data['bundle_platforms']
  x64_platform = Gem::Platform.local.cpu == 'x64'
  data['gem_platform_dependencies'].each_pair do |gem_platform, info|
    next if gem_platform == 'x86-mingw32' && x64_platform
    next if gem_platform == 'x64-mingw32' && !x64_platform
    if bundle_deps = info['gem_runtime_dependencies']
      bundle_platform = bundle_platforms[gem_platform] or raise "Missing bundle_platform"
      if bundle_platform == "all"
        bundle_deps.each_pair do |name, version|
          s.add_runtime_dependency(name, version)
        end
      else
        # important to use .to_s and not .os for the sake of Windows
        # .cpu  => x64
        # .os   => mingw32
        # .to_s => x64-mingw32
        if Gem::Platform.local.to_s == gem_platform
          bundle_deps.each_pair do |name, version|
            s.add_runtime_dependency(name, version)
          end
        end
      end
    end
  end
end
