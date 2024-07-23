Gem::Specification.new do |spec|
  spec.name = "puppet"
  spec.version = "7.32.1"
  spec.license = 'Apache-2.0'

  spec.required_rubygems_version = Gem::Requirement.new("> 1.3.1")
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")
  spec.authors = ["Puppet Labs"]
  spec.date = "2012-08-17"
  spec.description = <<~EOF
    Puppet, an automated administrative engine for your Linux, Unix, and Windows systems, performs administrative tasks
    (such as adding users, installing packages, and updating server configurations) based on a centralized specification.
  EOF
  spec.email = "info@puppetlabs.com"
  spec.executables = ["puppet"]
  spec.files = Dir['[A-Z]*'] + Dir['install.rb'] + Dir['bin/*'] + Dir['lib/**/*'] + Dir['conf/*'] + Dir['man/**/*'] + Dir['tasks/*'] + Dir['locales/**/*'] + Dir['ext/**/*'] + Dir['examples/**/*']
  spec.homepage = "https://github.com/puppetlabs/puppet"
  spec.rdoc_options = ["--title", "Puppet - Configuration Management", "--main", "README", "--line-numbers"]
  spec.require_paths = ["lib"]
  spec.summary = "Puppet, an automated configuration management tool"
  spec.specification_version = 4
  spec.add_runtime_dependency(%q<facter>, ["> 2.0.1", "< 5"])
  spec.add_runtime_dependency(%q<hiera>, [">= 3.2.1", "< 4"])
  spec.add_runtime_dependency(%q<semantic_puppet>, "~> 1.0")
  spec.add_runtime_dependency(%q<fast_gettext>, ">= 1.1", "< 3")
  spec.add_runtime_dependency(%q<locale>, "~> 2.1")
  spec.add_runtime_dependency(%q<multi_json>, "~> 1.10")
  spec.add_runtime_dependency(%q<puppet-resource_api>, "~> 1.5")
  spec.add_runtime_dependency(%q<concurrent-ruby>, "~> 1.0")
  spec.add_runtime_dependency(%q<deep_merge>, "~> 1.0")
  spec.add_runtime_dependency(%q<scanf>, "~> 1.0")

  # For building platform specific puppet gems...the --platform flag is only supported in newer Ruby versions
  platform = spec.platform.to_s
  if platform == 'universal-darwin'
    spec.add_runtime_dependency('CFPropertyList', '~> 2.2')
  end

  if platform == 'x64-mingw32' || platform == 'x86-mingw32'
    # ffi 1.16.0 - 1.16.2 are broken on Windows
    spec.add_runtime_dependency('ffi', '>= 1.15.5', '< 1.17.0', '!= 1.16.0', '!= 1.16.1', '!= 1.16.2')
    spec.add_runtime_dependency('minitar', '~> 0.9')
  end
end
