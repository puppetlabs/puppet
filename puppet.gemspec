Gem::Specification.new do |s|
  s.name = "puppet"
  version = "7.31.0"
  mdata = version.match(/(\d+\.\d+\.\d+)/)
  s.version = mdata ? mdata[1] : version
  s.license = 'Apache-2.0'

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1")
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0")
  s.authors = ["Puppet Labs"]
  s.date = "2012-08-17"
  s.description = <<~EOF
    Puppet, an automated administrative engine for your Linux, Unix, and Windows systems, performs administrative tasks
    (such as adding users, installing packages, and updating server configurations) based on a centralized specification.
  EOF
  s.email = "info@puppetlabs.com"
  s.executables = ["puppet"]
  s.files = Dir['[A-Z]*'] + Dir['install.rb'] + Dir['bin/*'] + Dir['lib/**/*'] + Dir['conf/*'] + Dir['man/**/*'] + Dir['tasks/*'] + Dir['locales/**/*'] + Dir['ext/**/*'] + Dir['examples/**/*']
  s.homepage = "https://github.com/puppetlabs/puppet"
  s.rdoc_options = ["--title", "Puppet - Configuration Management", "--main", "README", "--line-numbers"]
  s.require_paths = ["lib"]
  s.summary = "Puppet, an automated configuration management tool"
  s.specification_version = 4
  s.add_runtime_dependency(%q<facter>, ["> 2.0.1", "< 5"])
  s.add_runtime_dependency(%q<hiera>, [">= 3.2.1", "< 4"])
  s.add_runtime_dependency(%q<semantic_puppet>, "~> 1.0")
  s.add_runtime_dependency(%q<fast_gettext>, ">= 1.1", "< 3")
  s.add_runtime_dependency(%q<locale>, "~> 2.1")
  s.add_runtime_dependency(%q<multi_json>, "~> 1.10")
  s.add_runtime_dependency(%q<puppet-resource_api>, "~> 1.5")
  s.add_runtime_dependency(%q<concurrent-ruby>, "~> 1.0")
  s.add_runtime_dependency(%q<deep_merge>, "~> 1.0")
  s.add_runtime_dependency(%q<scanf>, "~> 1.0")

  # For building platform specific puppet gems...the --platform flag is only supported in newer Ruby versions
  platform = s.platform.to_s
  if platform == 'universal-darwin'
    s.add_runtime_dependency('CFPropertyList', '~> 2.2')
  end

  if platform == 'x64-mingw32' || platform == 'x86-mingw32'
    s.add_runtime_dependency('ffi', '1.15.5')
    s.add_runtime_dependency('minitar', '~> 0.9')
  end
end
