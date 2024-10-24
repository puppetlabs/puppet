Gem::Specification.new do |spec|
  spec.name = "puppet"
  spec.version = "8.11.0"
  spec.licenses = ['Apache-2.0']

  spec.required_rubygems_version = Gem::Requirement.new("> 1.3.1")
  spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")
  spec.authors = ["Puppet Labs"]
  spec.date = "2012-08-17"
  spec.description = <<~EOF
    Puppet, an automated administrative engine for your Linux, Unix, and Windows systems, performs administrative tasks
    (such as adding users, installing packages, and updating server configurations) based on a centralized specification.
  EOF
  spec.email = "info@puppetlabs.com"
  spec.executables = ["puppet"]
  spec.files = Dir['[A-Z]*'] + Dir['install.rb'] + Dir['bin/*'] + Dir['lib/**/*'] + Dir['conf/*'] + Dir['man/**/*'] + Dir['tasks/*'] + Dir['locales/**/*'] + Dir['ext/**/*'] + Dir['examples/**/*']
  spec.license = "Apache-2.0"
  spec.homepage = "https://github.com/puppetlabs/puppet"
  spec.rdoc_options = ["--title", "Puppet - Configuration Management", "--main", "README", "--line-numbers"]
  spec.require_paths = ["lib"]
  spec.summary = "Puppet, an automated configuration management tool"
  spec.specification_version = 4
  spec.add_runtime_dependency('concurrent-ruby', '~> 1.0')
  spec.add_runtime_dependency('deep_merge', '~> 1.0')
  spec.add_runtime_dependency('facter', ['>= 4.3.0', '< 5'])
  spec.add_runtime_dependency('fast_gettext', '>= 2.1', '< 4')
  spec.add_runtime_dependency('getoptlong', '~> 0.2.0')
  spec.add_runtime_dependency('locale', '~> 2.1')
  spec.add_runtime_dependency('multi_json', '~> 1.13')
  spec.add_runtime_dependency('puppet-resource_api', '~> 1.5')
  spec.add_runtime_dependency('scanf', '~> 1.0')
  spec.add_runtime_dependency('semantic_puppet', '~> 1.0')
  spec.add_runtime_dependency('ostruct', '~> 0.6.0')

  # If we're building a platform-specific gem, as indicated by spec.platform,
  # include the corresponding runtime dependencies no matter which platform we're
  # currently running on.
  #
  # If we're running in bundler, include runtime dependencies for the platform
  # we're currently running on.
  platform = spec.platform.to_s
  if platform =~ /darwin/ || (defined?(Bundler) && RUBY_PLATFORM =~ /darwin/)
    spec.add_runtime_dependency('CFPropertyList', ['>= 3.0.6', '< 4'])
  end

  if platform =~ /mingw/ || (defined?(Bundler) && Gem.win_platform?)
    # ffi 1.16.0 - 1.16.2 are broken on Windows
    spec.add_runtime_dependency('ffi', '>= 1.15.5', '< 1.17.0', '!= 1.16.0', '!= 1.16.1', '!= 1.16.2')
    spec.add_runtime_dependency('minitar', '~> 0.9')
  elsif platform =~ /java/ || (defined?(Bundler) && Gem.java_platform?)
    # don't depend on syslog on jruby, it requires extensions
  else
    spec.add_runtime_dependency('syslog', '~> 0.1.2')
  end
end
