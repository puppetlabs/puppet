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
require 'open3'

Dir['tasks/**/*.rake'].each { |t| load t }

if Rake.application.top_level_tasks.grep(/^(pl:|package:)/).any?
  begin
    require 'packaging'
    Pkg::Util::RakeUtils.load_packaging_tasks
  rescue LoadError => e
    puts "Error loading packaging rake tasks: #{e}"
  end
end

namespace :package do
  task :bootstrap do
    puts 'Bootstrap is no longer needed, using packaging-as-a-gem'
  end
  task :implode do
    puts 'Implode is no longer needed, using packaging-as-a-gem'
  end
end

task :default do
  sh %{rake -T}
end

task :spec do
  ENV["LOG_SPEC_ORDER"] = "true"
  sh %{rspec #{ENV['TEST'] || ENV['TESTS'] || 'spec'}}
end

desc 'run static analysis with rubocop'
task(:rubocop) do
  require 'rubocop'
  cli = RuboCop::CLI.new
  exit_code = cli.run(%w(--display-cop-names --format simple))
  raise "RuboCop detected offenses" if exit_code != 0
end

desc "verify that changed files are clean of Ruby warnings"
task(:warnings) do
  # This rake task looks at all files modified in this branch.
  commit_range = 'HEAD^..HEAD'
  ruby_files_ok = true
  puts "Checking modified files #{commit_range}"
  %x{git diff --diff-filter=ACM --name-only #{commit_range}}.each_line do |modified_file|
    modified_file.chomp!
    # Skip racc generated file as it can have many warnings that cannot be manually fixed
    next if modified_file.end_with?("pops/parser/eparser.rb")
    next if modified_file.start_with?('spec/fixtures/', 'acceptance/fixtures/') || File.extname(modified_file) != '.rb'
    puts modified_file

    stdout, stderr, _ = Open3.capture3("ruby -wc \"#{modified_file}\"")
    unless stderr.empty?
      ruby_files_ok = false
      puts stderr
    end
    puts stdout
  end
  raise "One or more ruby files contain warnings." unless ruby_files_ok
end

if Rake.application.top_level_tasks.grep(/^gettext:/).any?
  begin
    spec = Gem::Specification.find_by_name 'gettext-setup'
    load "#{spec.gem_dir}/lib/tasks/gettext.rake"
    GettextSetup.initialize(File.absolute_path('locales', File.dirname(__FILE__)))
  rescue LoadError
    abort("Run `bundle install --with documentation` to install the `gettext-setup` gem.")
  end
end
