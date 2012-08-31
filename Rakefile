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
require 'yaml'

Dir['tasks/**/*.rake'].each { |t| load t }
Dir['ext/packaging/tasks/**/*'].sort.each { |t| load t }

begin
  @build_defaults ||= YAML.load_file('ext/build_defaults.yaml')
  @packaging_url  = @build_defaults['packaging_url']
  @packaging_repo = @build_defaults['packaging_repo']
rescue
  STDERR.puts 'Unable to read the packaging repo info from ext/build_defaults.yaml'
end

namespace :package do
  desc "Bootstrap packaging automation, e.g. clone into packaging repo"
  task :bootstrap do
    if File.exist?("ext/#{@packaging_repo}")
      puts "It looks like you already have ext/#{@packaging_repo}. If you don't like it, blow it away with package:implode."
    else
      cd 'ext' do
        %x{git clone #{@packaging_url}}
      end
    end
  end
  desc "Remove all cloned packaging automation"
  task :implode do
    rm_rf "ext/#{@packaging_repo}"
  end
end


task :default do
    sh %{rake -T}
end

RSpec::Core::RakeTask.new do |t|
    t.pattern ='spec/{unit,integration}/**/*.rb'
    t.fail_on_error = true
end
