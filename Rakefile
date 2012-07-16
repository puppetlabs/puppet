# Rakefile for Puppet -*- ruby -*-

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
task :puppetpackages => [:gem, :package]

RSpec::Core::RakeTask.new do |t|
    t.pattern ='spec/{unit,integration}/**/*.rb'
    t.fail_on_error = true
end
