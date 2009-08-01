# Rakefile for Puppet -*- ruby -*-

$: << File.expand_path('lib')
$LOAD_PATH << File.join(File.dirname(__FILE__), 'tasks')

Dir['tasks/**/*.rake'].each { |t| load t }

require './lib/puppet.rb'
require 'rake'
require 'rake/packagetask'
require 'rake/gempackagetask'

FILES = FileList[
    '[A-Z]*',
    'install.rb',
    'bin/**/*',
    'sbin/**/*',
    'lib/**/*',
    'conf/**/*',
    'man/**/*',
    'examples/**/*',
    'ext/**/*',
    'test/**/*',
    'spec/**/*'
]

task :default do
    sh %{rake -T}
end

spec = Gem::Specification.new do |spec|
    spec.platform = Gem::Platform::RUBY
    spec.name = 'puppet'
    spec.files = FILES.to_a
    spec.version = Puppet::PUPPETVERSION
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

Rake::PackageTask.new("puppet", Puppet::PUPPETVERSION) do |pkg|
    pkg.package_dir = 'pkg'
    pkg.need_tar_gz = true
    pkg.package_files = FILES.to_a
end

Rake::GemPackageTask.new(spec) do |pkg|
end

desc "Run the specs under spec/"
task :spec do
    require 'spec'
    require 'spec/rake/spectask'
    begin
        require 'rcov'
    rescue LoadError
    end

    Spec::Rake::SpecTask.new do |t|
        t.spec_opts = ['--format','s', '--loadby','mtime']
        t.spec_files = FileList['spec/**/*.rb']
        if defined?(Rcov)
            t.rcov = true
            t.rcov_opts = ['--exclude', 'spec/*,test/*,results/*,/usr/lib/*']
        end
     end
end

desc "Run the unit tests"
task :unit do
    sh "cd test; rake"
end
