# Rakefile for Puppet

$: << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

begin
    require 'rake/reductive'
rescue LoadError
    $stderr.puts "You must have the Reductive build library in your RUBYLIB."
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
        'test/**/*.rb',
        'bin/**/*',
        'ext/**/*',
        'examples/**/*',
        'conf/**/*'
    ]

    p.add_dependency('facter', '1.1.0')

    #p.epmhosts = %w{culain}
    p.sunpkghost = "sol10b"
    p.rpmhost = "fedora1"
end

if project.has?(:gem)
    # Make our gem task.  This actually just fills out the spec.
    project.mkgemtask do |task|

        task.require_path = 'lib'                         # Use these for libraries.

        task.bindir = "bin"                               # Use these for applications.
        task.executables = ["puppet", "puppetd", "puppetmasterd", "puppetdoc",
                         "puppetca"]
        task.default_executable = "puppet"
        task.autorequire = 'puppet'

        #### Documentation and testing.

        task.has_rdoc = true
        #s.extra_rdoc_files = rd.rdoc_files.reject { |fn| fn =~ /\.rb$/ }.to_a
        task.rdoc_options <<
            '--title' <<  'Puppet - Configuration Management' <<
            '--main' << 'README' <<
            '--line-numbers'
        task.test_file = "test/Rakefile"
    end
end

if project.has?(:epm)
    project.mkepmtask do |task|
        task.bins = FileList.new("bin/puppet", "bin/puppetca")
        task.sbins = FileList.new("bin/puppetmasterd", "bin/puppetd")
        task.rubylibs = FileList.new('lib/**/*')
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

file "debian" => :bzr_is_runnable do
    system("bzr get http://www.hezmatt.org/~mpalmer/bzr/puppet.debian.svn debian") || exit(1)
end

task :check_build_deps => 'dpkg-checkbuilddeps_is_runnable' do
    system("dpkg-checkbuilddeps") || exit(1)
end

task :debian_packages => [ "debian", :check_build_deps, :fakeroot_is_runnable ] do
    system("fakeroot debian/rules clean") || exit(1)
    system("fakeroot debian/rules binary") || exit(1)
end

# $Id$
