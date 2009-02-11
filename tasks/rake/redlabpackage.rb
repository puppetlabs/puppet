#!/usr/bin/env ruby

# A raw platform for creating packages.

require 'rbconfig'
require 'rake'
require 'rake/tasklib'

# The PackageTask will create the following targets:
#
# [<b>:clobber_package</b>]
#   Delete all the package files.  This target is automatically
#   added to the main clobber target.
#
# [<b>:repackage</b>]
#   Rebuild the package files from scratch, even if they are not out
#   of date.
#
# [<b>"<em>package_dir</em>/<em>name</em>-<em>version</em>.tgz"</b>]
#   Create a gzipped tar package (if <em>need_tar</em> is true).  
#
# [<b>"<em>package_dir</em>/<em>name</em>-<em>version</em>.tar.gz"</b>]
#   Create a gzipped tar package (if <em>need_tar_gz</em> is true).  
#
# [<b>"<em>package_dir</em>/<em>name</em>-<em>version</em>.tar.bz2"</b>]
#   Create a bzip2'd tar package (if <em>need_tar_bz2</em> is true).  
#
# [<b>"<em>package_dir</em>/<em>name</em>-<em>version</em>.zip"</b>]
#   Create a zip package archive (if <em>need_zip</em> is true).
#
# Example:
#
#   Rake::PackageTask.new("rake", "1.2.3") do |p|
#     p.need_tar = true
#     p.package_files.include("lib/**/*.rb")
#   end
#
class Rake::RedLabPackageTask < Rake::TaskLib
    # The different directory types we can manage.
    DIRTYPES = {
        :bindir => :bins,
        :sbindir => :sbins,
        :sitelibdir => :rubylibs
    }

    # Name of the package (from the GEM Spec).
    attr_accessor :name

    # Version of the package (e.g. '1.3.2').
    attr_accessor :version

    # Directory used to store the package files (default is 'pkg').
    attr_accessor :package_dir

    # The directory to which to publish packages and html and such.
    attr_accessor :publishdir

    # The package-specific publishing directory
    attr_accessor :pkgpublishdir

    # The Product name.  Defaults to a capitalized version of the
    # package name
    attr_accessor :product

    # The copyright message.
    attr_accessor :copyright

    # The vendor.
    attr_accessor :vendor

    # The license file.  Defaults to COPYING.
    attr_accessor :license

    # The readme file.  Defaults to README.
    attr_accessor :readme

    # The description.
    attr_accessor :description

    # The summary.
    attr_accessor :summary

    # The directory in which to put the binaries.  Defaults to the system
    # default.
    attr_accessor :bindir

    # The executables.
    attr_accessor :bins

    # The directory in which to put the system binaries.  Defaults to the
    # system default.
    attr_accessor :sbindir

    # The system binaries.
    attr_accessor :sbins

    # The libraries.
    attr_accessor :rubylibs

    # The directory in which to put Ruby libraries.  Defaults to the
    # system site_dir.
    attr_accessor :sitelibdir

    # The URL for the package.
    attr_accessor :url
    
    # The source for the package.
    attr_accessor :source

    # Our operating system.
    attr_reader :os

    # Add a required package.
    def add_dependency(name, version = nil)
        @requires[name] = version
    end

    # Create the tasks defined by this task library.
    def define
        fail "Version required (or :noversion)" if @version.nil?
        @version = nil if :noversion == @version

        directory pkgdest
        file pkgdest => self.package_dir

        directory self.package_dir

        self.mkcopytasks

        self
    end

    # Return the list of files associated with a dirname.
    def files(dirname)
        if @dirtypes.include?(dirname)
            return self.send(@dirtypes[dirname])
        else
            raise "Could not find directory type %s" % dirname
        end
    end

    # Create a Package Task with the given name and version. 
    def initialize(name=nil, version=nil)
        # Theoretically, one could eventually add directory types here.
        @dirtypes = DIRTYPES.dup

        @requires = {}

        @name           = name
        @version        = version
        @package_dir    = 'pkg'
        @product        = name.capitalize

        @bindir         = Config::CONFIG["bindir"]
        @sbindir        = Config::CONFIG["sbindir"]
        @sitelibdir     = Config::CONFIG["sitelibdir"]

        @license        = "COPYING"
        @readme         = "README"

        yield self if block_given?

        define unless name.nil?

        # Make sure they've provided everything necessary.
        %w{copyright vendor description}.each do |attr|
            unless self.send(attr)
                raise "You must provide the attribute %s" % attr
            end
        end
    end

    # Make tasks for copying/linking all of the necessary files.
    def mkcopytasks
        basedir = pkgdest()

        tasks = []

        # Iterate across all of the file locations...
        @dirtypes.each do |dirname, filemethod|
            tname = ("copy" + dirname.to_s).intern

            dir = self.send(dirname)

            reqs = []

            # This is where we're putting the files.
            targetdir = self.targetdir(dirname)

            # Make sure our target directories exist
            directory targetdir
            file targetdir => basedir

            # Get the file list and remove the leading directory.
            files = self.files(dirname) or next

            reqs = []
            files.each do |sourcefile|
                # The file without the basedir.  This is necessary because
                # files are created with the path from ".", but they often
                # have 'lib' changed to 'site_ruby' or something similar.
                destfile = File.join(targetdir, sourcefile.sub(/^\w+\//, ''))
                reqs << destfile

                # Make sure the base directory is listed as a prereq
                sourcedir = File.dirname(sourcefile)
                destdir = nil
                unless sourcedir == "."
                    destdir = File.dirname(destfile)
                    reqs << destdir
                    directory(destdir)
                end

                # Now make the task associated with creating the object in
                # question.
                if FileTest.directory?(sourcefile)
                    directory(destfile)
                else
                    file(destfile => sourcefile) do
                        if FileTest.exists?(destfile)
                            if File.stat(sourcefile) > File.stat(destfile)
                                rm_f destfile
                                safe_ln(sourcefile, destfile)
                            end
                        else
                            safe_ln(sourcefile, destfile)
                        end
                    end
                    
                    # If we've set the destdir, then list it as a prereq.
                    if destdir
                        file destfile => destdir
                    end
                end
            end

            # And create a task for each one
            task tname => reqs
             
            # And then mark our task as a prereq
            tasks << tname
        end

        task :copycode => [self.package_dir, pkgdest]

        task :copycode => tasks do
            puts "Finished copying"
        end
    end

    # Where we're copying a given type of file.
    def targetdir(dirname)
        File.join(pkgdest(), self.send(dirname)).sub("//", "/")
    end

    private

    def package_name
        @version ? "#{@name}-#{@version}" : @name
    end

    def package_dir_path
        "#{package_dir}/#{package_name}"
    end
end
