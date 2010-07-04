# Rakefile for Puppet -*- ruby -*-

$LOAD_PATH << File.join(File.dirname(__FILE__), 'tasks')

require 'rake'
require 'rake/packagetask'
require 'rake/gempackagetask'

module Puppet
    PUPPETVERSION = File.read('lib/puppet.rb')[/PUPPETVERSION *= *'(.*)'/,1] or fail "Couldn't find PUPPETVERSION"
end

Dir['tasks/**/*.rake'].each { |t| load t }

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
    'tasks/**/*',
    'test/**/*',
    'spec/**/*'
]

Rake::PackageTask.new("puppet", Puppet::PUPPETVERSION) do |pkg|
    pkg.package_dir = 'pkg'
    pkg.need_tar_gz = true
    pkg.package_files = FILES.to_a
end

task :default do
    sh %{rake -T}
end

desc "Create the tarball and the gem - use when releasing"
task :puppetpackages => [:create_gem, :package]

desc "Run the specs under spec/"
task :spec do
    require 'spec'
    require 'spec/rake/spectask'
    begin
#        require 'rcov'
    rescue LoadError
    end

    Spec::Rake::SpecTask.new do |t|
        t.spec_opts = ['--format','s', '--loadby','mtime', '--color']
        t.spec_files = FileList['spec/**/*.rb']
        t.fail_on_error = false
        if defined?(Rcov)
            t.rcov = true
            t.rcov_opts = ['--exclude', 'spec/*,test/*,results/*,/usr/lib/*,/usr/local/lib/*']
        end
     end
end

desc "Run the unit tests"
task :unit do
    sh "cd test; rake"
end
