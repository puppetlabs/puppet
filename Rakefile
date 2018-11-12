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

begin
  require 'packaging'
  Pkg::Util::RakeUtils.load_packaging_tasks
rescue LoadError => e
  puts "Error loading packaging rake tasks: #{e}"
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
  sh %{rspec #{ENV['TEST'] || ENV['TESTS'] || 'spec'}}
end

desc 'run static analysis with rubocop'
task(:rubocop) do
  if RUBY_VERSION < '2.0'
    puts 'rubocop tests require Ruby 2.0 or higher'
    puts 'skipping rubocop'
  else
    require 'rubocop'
    cli = RuboCop::CLI.new
    exit_code = cli.run(%w(--display-cop-names --format simple))
    raise "RuboCop detected offenses" if exit_code != 0
  end
end

desc "verify that commit messages match CONTRIBUTING.md requirements"
task(:commits) do
  # This rake task looks at the summary from every commit from this branch not
  # in the branch targeted for a PR. This is accomplished by using the
  # TRAVIS_COMMIT_RANGE environment variable, which is present in travis CI and
  # populated with the range of commits the PR contains. If not available, this
  # falls back to `master..HEAD` as a next best bet as `master` is unlikely to
  # ever be absent.
  commit_range = ENV['TRAVIS_COMMIT_RANGE'].nil? ? 'master..HEAD' : ENV['TRAVIS_COMMIT_RANGE'].sub(/\.\.\./, '..')
  puts "Checking commits #{commit_range}"
  %x{git log --no-merges --pretty=%s #{commit_range}}.each_line do |commit_summary|
    # This regex tests for the currently supported commit summary tokens: maint, doc, packaging, or pup-<number>.
    # The exception tries to explain it in more full.
    if /^\((maint|doc|docs|packaging|l10n|pup-\d+)\)|revert/i.match(commit_summary).nil?
      raise "\n\n\n\tThis commit summary didn't match CONTRIBUTING.md guidelines:\n" \
        "\n\t\t#{commit_summary}\n" \
        "\tThe commit summary (i.e. the first line of the commit message) should start with one of:\n"  \
        "\t\t(PUP-<digits>) # this is most common and should be a ticket at tickets.puppet.com\n" \
        "\t\t(docs)\n" \
        "\t\t(docs)(DOCUMENT-<digits>)\n" \
        "\t\t(maint)\n" \
        "\t\t(packaging)\n" \
        "\t\t(L10n)\n" \
        "\n\tThis test for the commit summary is case-insensitive.\n\n\n"
    else
      puts "#{commit_summary}"
    end
    puts "...passed"
  end
end

desc "verify that changed files are clean of Ruby warnings"
task(:warnings) do
  # This rake task looks at all files modified in this branch. This is
  # accomplished by using the TRAVIS_COMMIT_RANGE environment variable, which
  # is present in travis CI and populated with the range of commits the PR
  # contains. If not available, this falls back to `master..HEAD` as a next
  # best bet as `master` is unlikely to ever be absent.
  commit_range = ENV['TRAVIS_COMMIT_RANGE'].nil? ? 'master...HEAD' : ENV['TRAVIS_COMMIT_RANGE']
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
  end
end
