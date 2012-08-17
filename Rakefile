# Rakefile for Puppet -*- ruby -*-

# We need access to the Puppet.version method
$LOAD_PATH.unshift(File.expand_path("lib"))
require 'puppet/version'

$LOAD_PATH << File.join(File.dirname(__FILE__), 'tasks')

begin
  require 'rubygems'
  require 'rubygems/package_task'
rescue LoadError
  # Users of older versions of Rake (0.8.7 for example) will not necessarily
  # have rubygems installed, or the newer rubygems package_task for that
  # matter.
  require 'rake/packagetask'
  require 'rake/gempackagetask'
end

require 'rake'
require 'rspec'
require "rspec/core/rake_task"


%x{which git &> /dev/null}
if $?.success? and File.exist?('.git')
  # remove the git hash from git describe string
  Puppet.version = %x{git describe}.chomp.gsub('-','.').split('.')[0..3].join('.')
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

Rake::PackageTask.new("puppet", Puppet.version) do |pkg|
    pkg.package_dir = 'pkg'
    pkg.need_tar_gz = true
    pkg.package_files = FILES.to_a
end

task :default do
    sh %{rake -T}
end

desc "Create the tarball and the gem - use when releasing"
task :puppetpackages => [:create_gem, :package]

RSpec::Core::RakeTask.new do |t|
    t.pattern ='spec/{unit,integration}/**/*.rb'
    t.fail_on_error = true
end

desc "Run the unit tests"
task :unit do
  Dir.chdir("test") { sh "rake" }
end
