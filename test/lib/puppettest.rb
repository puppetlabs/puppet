require 'puppettest/support/helpers'

module PuppetTest
    include PuppetTest::Support::Helpers

    def cleanup(&block)
        @@cleaners << block
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

        if $0 =~ /.+\.rb/ or Puppet[:debug]
            Puppet::Log.newdestination :console
            Puppet::Log.level = :debug
            #$VERBOSE = 1
            Puppet.info @method_name
        else
            Puppet::Log.close
            Puppet::Log.newdestination tempfile()
            Puppet[:httplog] = tempfile()
        end

        Puppet[:ignoreschedules] = true
    end

    def tempfile
        if defined? @@tmpfilenum
            @@tmpfilenum += 1
        else
            @@tmpfilenum = 1
        end

        f = File.join(self.tmpdir(), self.class.to_s + "_" + @method_name +
                      @@tmpfilenum.to_s)
        @@tmpfiles << f
        return f
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
        stopservices

        @@cleaners.each { |cleaner| cleaner.call() }

        @@tmpfiles.each { |file|
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
        Puppet::Rails.clear
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
        Process.waitall
        if File.stat("/dev/null").mode & 007777 != 0666
            File.open("/tmp/nullfailure", "w") { |f|
                f.puts self.class
            }
            exit(74)
        end
    end
end

# $Id$
