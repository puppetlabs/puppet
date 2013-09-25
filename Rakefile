# Rakefile for Puppet -*- ruby -*-
RAKE_ROOT = File.dirname(__FILE__)

# We need access to the Puppet.version method
$LOAD_PATH.unshift(File.expand_path("lib"))
require 'puppet/version'

$LOAD_PATH << File.join(RAKE_ROOT, 'tasks')

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

Dir['tasks/**/*.rake'].each { |t| load t }

begin
  load File.join(RAKE_ROOT, 'ext', 'packaging', 'packaging.rake')
rescue LoadError
end

build_defs_file = 'ext/build_defaults.yaml'
if File.exist?(build_defs_file)
  begin
    require 'yaml'
    @build_defaults ||= YAML.load_file(build_defs_file)
  rescue Exception => e
    STDERR.puts "Unable to load yaml from #{build_defs_file}:"
    STDERR.puts e
  end
  @packaging_url  = @build_defaults['packaging_url']
  @packaging_repo = @build_defaults['packaging_repo']
  raise "Could not find packaging url in #{build_defs_file}" if @packaging_url.nil?
  raise "Could not find packaging repo in #{build_defs_file}" if @packaging_repo.nil?

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
end

task :default do
  sh %{rake -T}
end

task :spec do
  sh %{rspec -fd spec}
end

namespace "ci" do
  task :spec do
    ENV["LOG_SPEC_ORDER"] = "true"
    sh %{rspec -r yarjuf -f JUnit -o result.xml -fd spec}
  end

  desc <<-EOS
    Check to see if the job at the url given in DOWNSTREAM_JOB has begun a build including the given BUILD_SELECTOR parameter.  An example `rake ci:check_for_downstream DOWNSTREAM_JOB='http://jenkins-foss.delivery.puppetlabs.net/job/Puppet-Package-Acceptance-master' BUILD_SELECTOR=123`
  EOS
  task :check_for_downstream do
    downstream_url = ENV['DOWNSTREAM_JOB'] || raise('No ENV DOWNSTREAM_JOB set!')
    downstream_url += '/api/json?depth=1'
    expected_selector = ENV['BUILD_SELECTOR'] || raise('No ENV BUILD_SELECTOR set!')
    puts "Waiting for a downstream job calling for BUILD_SELECTOR #{expected_selector}"
    success = false
    require 'json'
    require 'timeout'
    require 'net/http'
    Timeout.timeout(15 * 60) do
      loop do
        uri = URI(downstream_url)
        status = Net::HTTP.get(uri)
        json = JSON.parse(status)
        actions = json['builds'].first['actions']
        parameters = actions.select { |h| h.key?('parameters') }.first["parameters"]
        build_selector = parameters.select { |h| h['name'] == 'BUILD_SELECTOR' }.first['value']
        puts " * downstream job's last build selector: #{build_selector}"
        break if build_selector >= expected_selector
        sleep 60
      end
    end
  end

  desc "Tar up the acceptance/ directory so that package test runs have tests to run against."
  task :acceptance_artifacts do
    sh "cd acceptance; rm -f acceptance-artifacts.tar.gz; tar -czv --exclude .bundle -f acceptance-artifacts.tar.gz *"
  end
end
