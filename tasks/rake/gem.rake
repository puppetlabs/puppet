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

spec = Gem::Specification.new do |spec|
    spec.platform = Gem::Platform::RUBY
    spec.name = 'puppet'
    spec.files = GEM_FILES.to_a
    spec.executables = %w{puppetca puppetd puppetmasterd puppetqd puppetrun filebucket pi puppet puppetdoc ralsh} 
    spec.version = Puppet::PUPPETVERSION
    spec.add_dependency('facter', '>= 1.5.1')
    spec.summary = 'Puppet, an automated configuration management tool'
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
    sh "mv sbin/* bin"
end

desc "Create the gem"
task :create_gem => :prepare_gem do
    sh "mkdir -p pkg"
    Gem::Builder.new(spec).build
    sh "mv *.gem pkg"
    sh "rm bin/*"
    sh "git reset --hard"
end
