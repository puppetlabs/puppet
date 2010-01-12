require 'ftools'

GEM_FILES = FileList[
    '[A-Z]*',
    'install.rb',
    'bin/**/*',
    'lib/**/*',
    'conf/**/*',
    'man/**/*',
    'examples/**/*',
    'ext/**/*',
    'tasks/**/*',
    'test/**/*',
    'spec/**/*'
]

EXECUTABLES = FileList[
    'bin/**/*',
    'sbin/**/*'
]

SBIN = Dir.glob("sbin/*")

spec = Gem::Specification.new do |spec|
    spec.platform = Gem::Platform::RUBY
    spec.name = 'puppet'
    spec.files = GEM_FILES.to_a
    spec.executables = EXECUTABLES.gsub(/sbin\/|bin\//, '').to_a
    spec.version = Puppet::PUPPETVERSION
    spec.add_dependency('facter', '>= 1.5.1')
    spec.summary = 'Puppet, an automated configuration management tool'
    spec.description = 'Puppet, an automated configuration management tool'
    spec.author = 'Reductive Labs'
    spec.email = 'puppet@reductivelabs.com'
    spec.homepage = 'http://reductivelabs.com'
    spec.rubyforge_project = 'puppet'
    spec.has_rdoc = true
    spec.rdoc_options <<
        '--title' <<  'Puppet - Configuration Management' <<
        '--main' << 'README' <<
        '--line-numbers'
end

desc "Prepare binaries for gem creation"
task :prepare_gem do
    SBIN.each do |f|
      File.copy(f,"bin")
    end
end

desc "Create the gem"
task :create_gem => :prepare_gem do
    Dir.mkdir("pkg") rescue nil
    Gem::Builder.new(spec).build
    File.move("puppet-#{Puppet::PUPPETVERSION}.gem", "pkg")
    SBIN.each do |f|
       File.unlink("bin/" + f.gsub(/sbin\//, ''))
    end
end
