# Rakefile for Puppet

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
        'lib/**/*.rb',
        'test/**/*.rb',
        'bin/**/*',
        'ext/**/*',
        'examples/**/*',
        'conf/**/*'
    ]

    p.add_dependency('facter', '1.1.0')
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
        task.test_file = "test/test"
    end
end

if project.has?(:epm)
    project.mkepmtask do |task|
        task.bins = FileList.new("bin/puppet", "bin/puppetca")
        task.sbins = FileList.new("bin/puppetmasterd", "bin/puppetd")
        task.rubylibs = FileList.new('lib/**/*')
    end
end

# $Id$
