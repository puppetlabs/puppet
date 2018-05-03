# -*- encoding: utf-8 -*-
#
# This gemspec can be built using 'gem build .gemspec'. If you'd like to
# build a platform-specific gem on a different machine, you can pass in the
# GEM_PLATFORM environment variable. For example, if you wanted to build
# a Windows gem on a Mac you can do:
#    GEM_PLATFORM=x86-mingw32 gem build .gemspec

PROJECT_ROOT = File.join(File.dirname(__FILE__))

Gem::Specification.new do |s|
  s.name = "puppet"

  ## READ THE GEM VERSION ##
  version_file = File.join(PROJECT_ROOT, 'lib', 'puppet', 'version.rb')
  version_line_regex = /[^\s]*VERSION = ['"](\d+\.\d+\.\d+)['"]/
  match_data = version_line_regex.match(File.read(version_file))
  s.version = match_data[1] if match_data
  ##

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1")
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")
  s.authors = ["Puppet Labs"]
  s.date = "2012-08-17"
  s.description = "Puppet, an automated configuration management tool"
  s.email = "info@puppetlabs.com"
  s.executables = ["puppet"]

  ## LIST THE GEM FILES ##
  includes = Dir.glob([
    # [A-Z]* handles README.md, CONTRIBUTOR.md, Gemfile, etc.
    '[A-Z]*',
    'install.rb',
    'bin/**/*',
    'lib/**/*',
    'conf/**/*',
    'man/**/*',
    'examples/**/*',
    'ext/**/*',
    'tasks/**/*',
    'spec/**/*',
    'locales/**/*'    
  ])

  # Internally we still build the gem with packaging when we are
  # about to ship it for a release, so we need to exclude the files
  # that it uses
  excludes = Dir.glob(['ext/packaging/**/*', 'pkg/**/*'])

  s.files = includes - excludes
  s.test_files = Dir.glob('spec/**/*')
  ##

  s.homepage = "https://github.com/puppetlabs/puppet"
  s.rdoc_options = ["--title", "Puppet - Configuration Management", "--main", "README", "--line-numbers"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "puppet"
  s.summary = "Puppet, an automated configuration management tool"
  s.specification_version = 3

  ## ADD RUNTIME DEPENDENCIES ##
  s.add_runtime_dependency(%q<facter>, [">= 2.0.1", "< 4"])
  s.add_runtime_dependency(%q<hiera>, [">= 3.2.1", "< 4"])
  # PUP-7115 - return to a gem dependency in Puppet 5
  s.add_runtime_dependency(%q<semantic_puppet>, ['~> 1.0'])
  # i18n support (gettext-setup and dependencies)
  s.add_runtime_dependency(%q<fast_gettext>, "~> 1.1.2")
  s.add_runtime_dependency(%q<locale>, "~> 2.1")
  s.add_runtime_dependency(%q<multi_json>, "~> 1.13")
  # hocon is an optional hiera backend shipped in puppet-agent packages
  s.add_runtime_dependency(%q<hocon>, "~> 1.0")
  # net-ssh is a runtime dependency of Puppet::Util::NetworkDevice::Transport::Ssh
  # Beaker 3.0.0 to 3.10.0 depends on net-ssh 3.3.0beta1
  # Beaker 3.11.0+ depends on net-ssh 4.0+
  # be lenient to allow module testing where Beaker and Puppet are in same Gemfile
  s.add_runtime_dependency(%q<net-ssh>, [">= 3.0", "< 5"]) if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.0.0')
  ##

  ## ADD PLATFORM SPECIFIC DEPENDENCIES (e.g. ffi, win32) ##

  # Use the current machine's platform unless an explicit override is given.
  # It is important to use .to_s and not .os for the sake of Windows
  #   .cpu  => x64
  #   .os   => mingw32
  #   .to_s => x64-mingw32
  platform = ENV['GEM_PLATFORM'] || Gem::Platform.local.to_s
 
  case platform
  when /darwin/
    s.add_runtime_dependency('CFPropertyList', '~> 2.2')
  when /x86-mingw32|x64-mingw32/
    # Pinning versions that require native extensions
 
    # ffi is pinned due to PUP-8438
    s.add_runtime_dependency('ffi', '<= 1.9.18')
 
    # win32-xxxx gems are pinned due to PUP-6445
    s.add_runtime_dependency('win32-dir', '= 0.4.9')
    s.add_runtime_dependency('win32-process', '= 0.7.5')
 
    # Use of win32-security is deprecated
    s.add_runtime_dependency('win32-security', '= 0.2.5')
    s.add_runtime_dependency('win32-service', '= 0.8.8')
    s.add_runtime_dependency('minitar', '~> 0.6.1')
  else
    # Pass-thru, this means our gem does not have any platform-specific
    # dependencies
  end

  ##
end
