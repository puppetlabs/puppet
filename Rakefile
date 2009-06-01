# Rakefile for Puppet -*- ruby -*-

$: << File.expand_path('lib')

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

task :tracdocs do
    require 'puppet'
    require 'puppet/util/reference'
    Puppet::Util::Reference.references.each do |ref| 
        sh "puppetdoc -m trac -r #{ref.to_s}"
    end
end

desc "Run the specs under spec/"
task :spec do
    require 'spec'
    require 'spec/rake/spectask'
    # require 'rcov'
    Spec::Rake::SpecTask.new do |t|
        t.spec_opts = ['--format','s', '--loadby','mtime'] 
        t.spec_files = FileList['spec/**/*.rb']
    end
end

desc "Run the unit tests"
task :unit do
    sh "cd test; rake"
end

desc "Prep CI RSpec tests"
task :ci_prep do
    require 'rubygems'
    begin
        gem 'ci_reporter'
        require 'ci/reporter/rake/rspec'
        require 'ci/reporter/rake/test_unit'
        ENV['CI_REPORTS'] = 'results'
    rescue LoadError 
       puts 'Missing ci_reporter gem. You must have the ci_reporter gem installed to run the CI spec tests'
    end 
end

desc "Run the CI RSpec tests"
task :ci_spec => [:ci_prep, 'ci:setup:rpsec', :spec]

desc "Run CI Unit tests"
task :ci_unit => [:ci_prep, 'ci:setup:testunit', :unit]

desc "Send patch information to the puppet-dev list"
task :mail_patches do
    if Dir.glob("00*.patch").length > 0
        raise "Patches already exist matching '00*.patch'; clean up first"
    end

    unless %x{git status} =~ /On branch (.+)/
        raise "Could not get branch from 'git status'"
    end
    branch = $1
    
    unless branch =~ %r{^([^\/]+)/([^\/]+)/([^\/]+)$}
        raise "Branch name does not follow <type>/<parent>/<name> model; cannot autodetect parent branch"
    end

    type, parent, name = $1, $2, $3

    # Create all of the patches
    sh "git format-patch -C -M -s -n --subject-prefix='PATCH/puppet' #{parent}..HEAD"

    # And then mail them out.

    # If we've got more than one patch, add --compose
    if Dir.glob("00*.patch").length > 1
        compose = "--compose"
    else
        compose = ""
    end

    # Now send the mail.
    sh "git send-email #{compose} --no-chain-reply-to --no-signed-off-by-cc --suppress-from --to puppet-dev@googlegroups.com 00*.patch"

    # Finally, clean up the patches
    sh "rm 00*.patch"
end

desc "Create a changelog based on your git commits."
task :changelog do
    CHANGELOG_DIR = "#{Dir.pwd}"
    mkdir(CHANGELOG_DIR) unless File.directory?(CHANGELOG_DIR)
    change_body=`git log --pretty=format:'%aD%n%an <%ae>%n%s%n'`
    File.open(File.join(CHANGELOG_DIR, "CHANGELOG.git"), 'w') do |f|
        f << change_body 
    end
 
    # Changelog commit
    `git add #{CHANGELOG_DIR}/CHANGELOG.git`
    `git commit -m "Update CHANGELOG.git"`
end
