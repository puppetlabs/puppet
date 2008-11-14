# Rakefile for Puppet -*- ruby -*-

$: << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

begin
    require 'rake/reductive'
rescue LoadError
    $stderr.puts "You must have the Reductive build library in your RUBYLIB; see http://github.com/lak/reductive-build/tree/master."
    exit(14)
end

TESTHOSTS = %w{rh3a fedora1 centos1 freebsd1 culain}

project = Rake::RedLabProject.new("puppet") do |p|
    p.summary = "System Automation and Configuration Management Software"
    p.description = "Puppet is a declarative language for expressing system
        configuration, a client and server for distributing it, and a library
        for realizing the configuration."

    p.filelist = [
        'install.rb',
        '[A-Z]*',
        'lib/puppet.rb',
        'lib/puppet/**/*.rb',
        'lib/puppet/**/*.py',
        'test/**/*',
        'spec/**/*',
        'bin/**/*',
        'ext/**/*',
        'examples/**/*',
        'conf/**/*',
        'man/**/*'
    ]
    p.filelist.exclude("bin/pi")

    p.add_dependency('facter', '1.1.0')
end

if project.has?(:gem)
    # Make our gem task.  This actually just fills out the spec.
    project.mkgemtask do |task|

        task.require_path = 'lib'                         # Use these for libraries.

        task.bindir = "bin"                               # Use these for applications.
        task.executables = ["puppet", "puppetd", "puppetmasterd", "puppetdoc",
                         "puppetca", "puppetrun", "ralsh"]
        task.default_executable = "puppet"

        #### Documentation and testing.

        task.has_rdoc = true
        #s.extra_rdoc_files = rd.rdoc_files.reject { |fn| fn =~ /\.rb$/ }.to_a
        task.rdoc_options <<
            '--title' <<  'Puppet - Configuration Management' <<
            '--main' << 'README' <<
            '--line-numbers'
        task.test_file = "test/Rakefile"
        task.author = "Luke Kanies"
    end
end

rule(/_is_runnable$/) do |t|
    available = false
    executable = t.name.sub(/_is_runnable$/, '')
    ENV['PATH'].split(':').each do |elem|
        available = true if File.executable? File.join(elem, executable)
    end
    
    unless available
        puts "You do not have #{executable} available in your path"
        exit 1
    end
end

task :check_build_deps => 'dpkg-checkbuilddeps_is_runnable' do
    system("dpkg-checkbuilddeps") || exit(1)
end

task :debian_packages => [ "debian", :check_build_deps, :fakeroot_is_runnable ] do
    system("fakeroot debian/rules clean") || exit(1)
    system("fakeroot debian/rules binary") || exit(1)
end


def dailyfile(package)
    "#{downdir}/#{package}/#{package}-daily-#{stamp}.tgz"
end

def daily(package)
    edir = "/tmp/daily-export"
    Dir.mkdir edir
    Dir.chdir(edir) do
        sh %{git clone git://reductivelabs.com/#{package} #{package} >/dev/null}
        sh %{tar cf - #{package} | gzip -c > #{dailyfile(package)}}
    end
    FileUtils.rm_rf(edir)
end

def downdir
    ENV['DOWNLOAD_DIR'] || "/opt/rl/docroots/reductivelabs.com/htdocs/downloads"
end

def stamp
    [Time.now.year, Time.now.month, Time.now.day].collect { |i| i.to_s}.join
end

pdaily = dailyfile("puppet")
fdaily = dailyfile("facter")

file pdaily do
    daily("puppet")
end

file fdaily do
    daily("facter")
end

task :daily => [pdaily, fdaily]

task :dailyclean do
    Dir.glob("#{downdir}/*/*daily*.tgz").each do |file|
        puts "Removing %s" % file
        File.unlink(file)
    end
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
    require 'rcov'
    Spec::Rake::SpecTask.new do |t|
         #   t.rcov = true
         t.spec_opts = ['--format','s', '--loadby','mtime']
         t.spec_files = FileList['spec/**/*.rb']
    end
end

desc "Run the unit tests"
task :unit do
    sh "cd test; rake"
end

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
    sh "git-format-patch -C -M -s -n #{parent}..HEAD"

    # And then mail them out.

    # If we've got more than one patch, add --compose
    if Dir.glob("00*.patch").length > 1
        compose = "--compose"
    else
        compose = ""
    end

    # Now send the mail.
    sh "git send-email #{compose} --no-chain-reply-to --no-signed-off-by-cc --suppress-from --no-thread --to puppet-dev@googlegroups.com 00*.patch"

    # Finally, clean up the patches
    sh "rm 00*.patch"
end
