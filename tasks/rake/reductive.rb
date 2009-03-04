#!/usr/bin/env ruby

# The tasks associated with building Reductive Labs projects

require 'rbconfig'
require 'rake'
require 'rake/tasklib'

require 'rake/clean'
require 'rake/testtask'

$features = {}

begin
    require 'rubygems'
    require 'rake/gempackagetask'
    $features[:gem] = true
rescue Exception
    $features[:gem] = false
    $stderr.puts "No Gems; skipping"
    nil
end

begin
    require 'rdoc/rdoc'
    $features[:rdoc] = true
rescue => detail
    $features[:rdoc] = false
    puts "No rdoc: %s" % detail
end

if $features[:rdoc]
    require 'rake/rdoctask'
end

# Create all of the standard targets for a Reductive Labs project.
# NOTE: The reason so many of the rake tasks are generated, rather than being
# declared directly, is that they need information from the project instance.
# Any rake task with an instance variable (e.g., @name or @version) needs
# to have that variable assigned *before* the task is defined.  Suckage.
class Rake::RedLabProject < Rake::TaskLib
    # The project name.
    attr_accessor :name

    # The project version.
    attr_accessor :version

    # The directory to which to publish packages and html and such.
    attr_accessor :publishdir

    # The package-specific publishing directory
    attr_accessor :pkgpublishdir

    # Create a Gem file.
    attr_accessor :mkgem

    # The hosts to run all of our tests on.
    attr_accessor :testhosts

    # The summary of this project.
    attr_accessor :summary

    # The description of this project.
    attr_accessor :description

    # The author of this project.
    attr_accessor :author

    # A Contact email address.
    attr_accessor :email

    # The URL for the project.
    attr_accessor :url

    # Where to get the source code.
    attr_accessor :source

    # Who the vendor is.
    attr_accessor :vendor

    # The copyright for this project
    attr_accessor :copyright

    # The RubyForge project.
    attr_accessor :rfproject

    # The list of files.  Only used for gem tasks.
    attr_writer :filelist

    # The directory in which to store packages. Defaults to "pkg".
    attr_accessor :package_dir

    # The default task.  Defaults to the 'alltests' task.
    attr_accessor :defaulttask

    # The defined requirements
    attr_reader :requires

    # The file containing the version string.
    attr_accessor :versionfile

    # Print messages on stdout
    def announce(msg = nil)
        puts msg
    end

    # Print messages on stderr
    def warn(msg = nil)
        $stderr.puts msg
    end

    def add_dependency(name, version)
        @requires[name] = version
    end

    # Where we'll be putting the code.
    def codedir
        unless defined? @codedir
            @codedir = File.join(self.package_dir, "#{@name}-#{@version}")
        end

        return @codedir
    end

    # Retrieve the current version from the code.
    def currentversion
        unless defined? @currentversion
            ver = %x{ruby -Ilib ./bin/#{@name} --version}.chomp
            if $? == 0 and ver != ""
                @currentversion = ver
            else
                warn "Could not retrieve current version; using 0.0.0"
                @currentversion = "0.0.0"
            end
        end

        return @currentversion
    end

    # Define all of our package tasks.  We just search through all of our
    # defined methods and call anything that's listed as making tasks.
    def define
        self.methods.find_all { |method| method.to_s =~ /^mktask/ }.each { |method|
            self.send(method)
        }
    end

    def egrep(pattern)
        Dir['**/*.rb'].each do |fn|
            count = 0
            open(fn) do |f|
                while line = f.gets
            count += 1
            if line =~ pattern
                puts "#{fn}:#{count}:#{line}"
            end
                end
            end
        end
    end

    # List all of the files.
    def filelist
        unless defined? @createdfilelist
            # If they passed in a file list as an array, then create a FileList
            # object out of it.
            if defined? @filelist
                unless @filelist.is_a? FileList
                    @filelist = FileList[@filelist]
                end
            else
                # Use a default file list.
                @filelist = FileList[
                    'install.rb',
                    '[A-Z]*',
                    'lib/**/*.rb',
                    'test/**/*.rb',
                    'bin/**/*',
                    'ext/**/*',
                    'examples/**/*',
                    'conf/**/*'
                ]
            end
            @filelist.delete_if {|item| item.include?(".git")}

            @createdfilelist = true
        end

        @filelist
    end

    def has?(feature)
        feature = feature.intern if feature.is_a? String
        if $features.include?(feature)
            return $features[feature]
        else
            return true
        end
    end

    def initialize(name, version = nil)
        @name = name

        if ENV['REL']
          @version = ENV['REL']
        else
          @version = version || self.currentversion
        end

        @defaulttask = :alltests
        @publishdir = "/opt/rl/docroots/reductivelabs.com/htdocs/downloads"
        @pkgpublishdir = "#{@publishdir}/#{@name}"

        @email = "dev@reductivelabs.com"
        @url = "http://reductivelabs.com/projects/#{@name}"
        @source = "http://reductivelabs.com/downloads/#{@name}/#{@name}-#{@version}.tgz"
        @vendor = "Reductive Labs, LLC"
        @copyright = "Copyright 2003-2008, Reductive Labs, LLC. Some Rights Reserved."
        @rfproject = @name

        @defaulttask = :package

        @package_dir = "pkg"

        @requires = {}

        @versionfile = "lib/#{@name}.rb"

        CLOBBER.include('doc/*')

        yield self if block_given?
        define if block_given?
    end

    def mktaskhtml
        if $features[:rdoc]
            Rake::RDocTask.new(:html) { |rdoc|
                rdoc.rdoc_dir = 'html'
                rdoc.template = 'html'
                rdoc.title    = @name.capitalize
                rdoc.options << '--line-numbers' << '--inline-source' <<
                                '--main' << 'README'
                rdoc.rdoc_files.include('README', 'COPYING', 'CHANGELOG')
                rdoc.rdoc_files.include('lib/**/*.rb')
                CLEAN.include("html")
            }

            # Publish the html.
            task :publish => [:package, :html] do
                puts Dir.getwd
                sh %{cp -r html #{self.pkgpublishdir}/apidocs}
            end
        else
            warn "No rdoc; skipping html"
        end
    end

    # Create a release task.
    def mktaskrelease
        desc "Make a new release"
        task :release => [
                :prerelease,
                :clobber,
                :update_version,
                :commit_newversion,
                :trac_version,
                :tag, # tag everything before we make a bunch of extra dirs
                :html,
                :package,
                :publish
              ] do
          
            announce 
            announce "**************************************************************"
            announce "* Release #{@version} Complete."
            announce "* Packages ready to upload."
            announce "**************************************************************"
            announce 
        end
    end

    # Do any prerelease work.
    def mktaskprerelease
        # Validate that everything is ready to go for a release.
        task :prerelease do
            announce 
            announce "**************************************************************"
            announce "* Making Release #{@version}"
            announce "* (current version #{self.currentversion})"
            announce "**************************************************************"
            announce  

            # Is a release number supplied?
            unless ENV['REL']
                warn "You must provide a release number when releasing"
                fail "Usage: rake release REL=x.y.z [REUSE=tag_suffix]"
            end

            # Is the release different than the current release.
            # (or is REUSE set?)
            if @version == self.currentversion && ! ENV['REUSE']
                fail "Current version is #{@version}, must specify REUSE=tag_suffix to reuse version"
            end

            # Are all source files checked in?
            if ENV['RELTEST']
                announce "Release Task Testing, skipping checked-in file test"
            else
                announce "Checking for unchecked-in files..."
                data = %x{git status}
                unless data.include?("nothing to commit")
                    fail "git status is not clean ... do you have unchecked-in files?"
                end
                announce "No outstanding checkins found ... OK"
            end
        end
    end

    # Create the task to update versions.
    def mktaskupdateversion
        task :update_version => [:prerelease] do
            if @version == self.currentversion
                announce "No version change ... skipping version update"
            else
                announce "Updating #{@versionfile} version to #{@version}"
                open(@versionfile) do |rakein|
                    open("#{@versionfile}.new", "w") do |rakeout|
                        rakein.each do |line|
                            if line =~ /^(\s*)#{@name.upcase}VERSION\s*=\s*/
                                rakeout.puts "#{$1}#{@name.upcase}VERSION = '#{@version}'"
                            else
                                rakeout.puts line
                            end
                        end
                    end
                end
                mv "#{@versionfile}.new", @versionfile

            end
        end

        desc "Commit the new versions to SVN."
        task :commit_newversion => [:update_version] do
            if ENV['RELTEST']
                announce "Release Task Testing, skipping commiting of new version"
            else
                sh %{git commit -m "Updated to version #{@version}" #{@versionfile}}
            end
        end
    end

    def mktasktrac_version
        task :trac_version => [:update_version] do
            tracpath = "/opt/rl/trac/#{@name}"

            unless FileTest.exists?(tracpath)
                announce "No Trac instance at %s" % tracpath
            else
                output = %x{sudo trac-admin #{tracpath} version list}.chomp.split("\n")
                versions = {}
                output[3..-1].each do |line|
                    name, time = line.chomp.split(/\s+/)
                    versions[name] = time
                end

                if versions.include?(@version)
                    announce "Version #{@version} already in Trac"
                else
                    announce "Adding #{@name} version #{@version} to Trac"
                    date = [Time.now.year.to_s,
                        Time.now.month.to_s,
                        Time.now.day.to_s].join("-")
                    system("sudo trac-admin #{tracpath} version add #{@version} #{date}")
                end
            end
        end
    end

    # Create the tag task.
    def mktasktag
        desc "Tag all the files with the latest release number (REL=x.y.z)"
        task :tag => [:prerelease] do
            reltag = @version
            announce "Tagging with [#{reltag}]"

            if ENV['RELTEST']
                announce "Release Task Testing, skipping tagging"
            else
                sh %{git tag #{reltag}}
            end
        end
    end

    # Create the task for testing across all hosts.
    def mktaskhosttest
        desc "Test Puppet on each test host"
        task :hosttest do
            out = ""
            TESTHOSTS.each { |host|
                puts "testing %s" % host
                cwd = Dir.getwd
                file = "/tmp/#{@name}-#{host}test.out"
                system("ssh #{host} 'cd git/#{@name}/test; sudo rake' 2>&1 >#{file}")

                if $? != 0
                    puts "%s failed; output is in %s" % [host, file]
                end
            }
        end
    end

    def mktaskri
        # Create a task to build the RDOC documentation tree.

        #Rake::RDocTask.new("ri") { |rdoc|
        #    #rdoc.rdoc_dir = 'html'
        #    #rdoc.template = 'html'
        #    rdoc.title    = "Puppet"
        #    rdoc.options << '--ri' << '--line-numbers' << '--inline-source' << '--main' << 'README'
        #    rdoc.rdoc_files.include('README', 'COPYING', 'CHANGELOG')
        #    rdoc.rdoc_files.include('lib/**/*.rb', 'doc/**/*.rdoc')
        #}

        if $features[:rdoc]
            task :ri do |ri|
                files = ['README', 'COPYING', 'CHANGELOG'] + Dir.glob('lib/**/*.rb')
                puts "files are \n%s" % files.join("\n")
                begin
                    ri = RDoc::RDoc.new
                    ri.document(["--ri-site"] + files)
                rescue RDoc::RDocError => detail
                    puts "Failed to build docs: %s" % detail
                    return nil
                rescue LoadError
                    puts "Missing rdoc; cannot build documentation"
                    return nil
                end
            end
        else
            warn "No rdoc; skipping ri."
        end
    end

    desc "Install the application using the standard install.rb script"
    task :install do
        ruby "install.rb"
    end

    def mktaskdefault
        if dtask = self.defaulttask
            desc "Default task"
            task :default => dtask
        end
    end

    desc "Run all unit tests."
    task :alltests do
        if FileTest.exists?("spec/Rakefile")
            sh %{cd spec; rake}
        else
            Dir.chdir("spec") do
                Dir.entries(".").find_all { |f| f =~ /\.rb/ }.each do |f|
                    sh %{ruby #{f}}
                end
            end
        end
    end

    desc "List all ruby files"
    task :rubyfiles do 
        puts Dir['**/*.rb'].reject { |fn| fn =~ /^pkg/ }
        puts Dir['**/bin/*'].reject { |fn| fn =~ /svn|(~$)|(\.rb$)/ }
    end

    desc "Look for TODO and FIXME tags in the code"
    task :todo do
        egrep "/#.*(FIXME|TODO|TBD)/"
    end

    # This task requires extra information from the Rake file.
    def mkgemtask
        # ====================================================================
        # Create a task that will package the Rake software into distributable
        # tar, zip and gem files.
        if ! defined?(Gem)
            puts "Package Target requires RubyGEMs"
        else
            spec = Gem::Specification.new { |s|

                #### Basic information.

                s.name = self.name
                s.version = self.version
                s.summary = self.summary
                s.description = self.description
                s.platform = Gem::Platform::RUBY

                #### Dependencies and requirements.

                # I'd love to explicitly list all of the libraries that I need,
                # but gems seem to only be able to handle dependencies on other
                # gems, which is, um, stupid.
                self.requires.each do |name, version|
                    s.add_dependency(name, ">= #{version}")
                end

                s.files = filelist.to_a

                #### Signing key and cert chain
                #s.signing_key = '/..../gem-private_key.pem'
                #s.cert_chain = ['gem-public_cert.pem']

                #### Author and project details.

                s.author = [self.author]
                s.email = self.email
                s.homepage = self.url
                s.rubyforge_project = self.rfproject

                yield s
            }

            Rake::GemPackageTask.new(spec) { |pkg|
                pkg.need_tar = true
            }

            desc "Copy the newly created package into the downloads directory"
            task :publish => [:package] do
                puts Dir.getwd
                sh %{cp pkg/#{@name}-#{@version}.gem #{self.publishdir}/gems}
                sh %{gem generate_index -d #{self.publishdir}}
                sh %{cp pkg/#{@name}-#{@version}.tgz #{self.pkgpublishdir}}
                sh %{ln -sf #{@name}-#{@version}.tgz #{self.pkgpublishdir}/#{@name}-latest.tgz}
            end
            CLEAN.include("pkg")
        end
    end
end
