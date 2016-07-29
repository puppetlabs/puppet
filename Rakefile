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
  sh %{rspec #{ENV['TEST'] || ENV['TESTS'] || 'spec'}}
end

desc 'run static analysis with rubocop'
task(:rubocop) do
  require 'rubocop'
  cli = RuboCop::CLI.new
  exit_code = cli.run(%w(--display-cop-names --format simple))
  raise "RuboCop detected offenses" if exit_code != 0
end

desc "verify that commit messages match CONTRIBUTING.md requirements"
task(:commits) do
  # This git command looks at the summary from every commit from this branch not in master.
  # Ideally this would compare against the branch that a PR is submitted against, but I don't
  # know how to get that information. Absent that, comparing with master should work in most cases.
  %x{git log --no-merges --pretty=%s master..$HEAD}.each_line do |commit_summary|
    # This regex tests for the currently supported commit summary tokens: maint, doc, packaging, or pup-<number>.
    # The exception tries to explain it in more full.
    if /^\((maint|doc|docs|packaging|pup-\d+)\)|revert/i.match(commit_summary).nil?
      raise "\n\n\n\tThis commit summary didn't match CONTRIBUTING.md guidelines:\n" \
        "\n\t\t#{commit_summary}\n" \
        "\tThe commit summary (i.e. the first line of the commit message) should start with one of:\n"  \
        "\t\t(pup-<digits>) # this is most common and should be a ticket at tickets.puppetlabs.com\n" \
        "\t\t(docs)\n" \
        "\t\t(maint)\n" \
        "\t\t(packaging)\n" \
        "\n\tThis test for the commit summary is case-insensitive.\n\n\n"
    end
  end
end
