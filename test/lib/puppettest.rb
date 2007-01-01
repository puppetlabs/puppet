# Add .../test/lib
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))
# Add .../lib
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../../lib')))

require 'puppet'
require 'test/unit'

# Yay; hackish but it works
if ARGV.include?("-d")
    Puppet.debug = true
end

module PuppetTest
    # Find the root of the Puppet tree; this is not the test directory, but
    # the parent of that dir.
    def basedir(*list)
        unless defined? @@basedir
            Dir.chdir(File.dirname(__FILE__)) do
                @@basedir = File.dirname(File.dirname(Dir.getwd))
            end
        end
        if list.empty?
            @@basedir
        else
            File.join(@@basedir, *list)
        end
    end

    def cleanup(&block)
        @@cleaners << block
    end

    def datadir(*list)
        File.join(basedir, "test", "data", *list)
    end

    def exampledir(*args)
        unless defined? @@exampledir
            @@exampledir = File.join(basedir, "examples")
        end

        if args.empty?
            return @@exampledir
        else
            return File.join(@@exampledir, *args)
        end
    end

    module_function :basedir, :datadir, :exampledir

    # Rails clobbers RUBYLIB, thanks
    def libsetup
        curlibs = ENV["RUBYLIB"].split(":")
        $:.reject do |dir| dir =~ /^\/usr/ end.each do |dir|
            unless curlibs.include?(dir)
                curlibs << dir
            end
        end

        ENV["RUBYLIB"] = curlibs.join(":")
    end
    
    def logcollector
        collector = []
        Puppet::Log.newdestination(collector)
        cleanup do
            Puppet::Log.close(collector)
        end
        collector
    end

    def rake?
        $0 =~ /rake_test_loader/
    end

    def setup
        @memoryatstart = Puppet::Util.memory
        if defined? @@testcount
            @@testcount += 1
        else
            @@testcount = 0
        end

        @configpath = File.join(tmpdir,
            self.class.to_s + "configdir" + @@testcount.to_s + "/"
        )

        unless defined? $user and $group
            $user = nonrootuser().uid.to_s
            $group = nonrootgroup().gid.to_s
        end

        Puppet.config.clear
        Puppet[:user] = $user
        Puppet[:group] = $group

        Puppet[:confdir] = @configpath
        Puppet[:vardir] = @configpath

        unless File.exists?(@configpath)
            Dir.mkdir(@configpath)
        end

        @@tmpfiles = [@configpath, tmpdir()]
        @@tmppids = []

        @@cleaners = []

        # If we're running under rake, then disable debugging and such.
        #if rake? or ! Puppet[:debug]
        if rake?
            Puppet::Log.close
            Puppet::Log.newdestination tempfile()
            Puppet[:httplog] = tempfile()
        else    
            if textmate?
                Puppet[:color] = false
            end
            Puppet::Log.newdestination :console
            Puppet::Log.level = :debug
            #$VERBOSE = 1
            Puppet.info @method_name
            Puppet[:trace] = true
        end

        Puppet[:ignoreschedules] = true
    end

    def tempfile
        if defined? @@tmpfilenum
            @@tmpfilenum += 1
        else
            @@tmpfilenum = 1
        end

        f = File.join(self.tmpdir(), self.class.to_s + "_" + @method_name.to_s +
                      @@tmpfilenum.to_s)
        @@tmpfiles << f
        return f
    end
    
    def textmate?
        if ENV["TM_FILENAME"]
            return true
        else
            return false
        end
    end

    def tstdir
        dir = tempfile()
        Dir.mkdir(dir)
        return dir
    end

    def tmpdir
        unless defined? @tmpdir and @tmpdir
            @tmpdir = case Facter["operatingsystem"].value
                      when "Darwin": "/private/tmp"
                      when "SunOS": "/var/tmp"
                      else
            "/tmp"
                      end


            @tmpdir = File.join(@tmpdir, "puppettesting")

            unless File.exists?(@tmpdir)
                FileUtils.mkdir_p(@tmpdir)
                File.chmod(01777, @tmpdir)
            end
        end
        @tmpdir
    end

    def teardown
        @@cleaners.each { |cleaner| cleaner.call() }

        @@tmpfiles.each { |file|
            unless file =~ /tmp/
                puts "Not deleting tmpfile %s" % file
                next
            end
            if FileTest.exists?(file)
                system("chmod -R 755 %s" % file)
                system("rm -rf %s" % file)
            end
        }
        @@tmpfiles.clear

        @@tmppids.each { |pid|
            %x{kill -INT #{pid} 2>/dev/null}
        }

        @@tmppids.clear
        Puppet::Type.allclear
        Puppet::Storage.clear
        Puppet.clear

        @memoryatend = Puppet::Util.memory
        diff = @memoryatend - @memoryatstart

        if diff > 1000
            Puppet.info "%s#%s memory growth (%s to %s): %s" %
                [self.class, @method_name, @memoryatstart, @memoryatend, diff]
        end

        # reset all of the logs
        Puppet::Log.close

        # Just in case there are processes waiting to die...
        require 'timeout'

        begin
            Timeout::timeout(5) do
                Process.waitall
            end
        rescue Timeout::Error
            # just move on
        end
        if File.stat("/dev/null").mode & 007777 != 0666
            File.open("/tmp/nullfailure", "w") { |f|
                f.puts self.class
            }
            exit(74)
        end
    end
end

require 'puppettest/support'
require 'puppettest/filetesting'
require 'puppettest/fakes'
require 'puppettest/exetest'
require 'puppettest/parsertesting'
require 'puppettest/servertest'

# $Id$
