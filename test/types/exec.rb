if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'
require 'facter'

class TestExec < Test::Unit::TestCase
	include TestPuppet
    def test_execution
        command = nil
        output = nil
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "/bin/echo"
            )
        }
        assert_nothing_raised {
            command.evaluate
        }
        assert_events([:executed_command], command)
    end

    def test_numvsstring
        [0, "0"].each { |val|
            Puppet.type(:exec).clear
            Puppet.type(:component).clear
            command = nil
            output = nil
            assert_nothing_raised {
                command = Puppet.type(:exec).create(
                    :command => "/bin/echo",
                    :returns => val
                )
            }
            assert_events([:executed_command], command)
        }
    end

    def test_path_or_qualified
        command = nil
        output = nil
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "echo"
            )
            assert_nil(command)
        }
        Puppet.type(:exec).clear
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "echo",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin"
            )
        }
        Puppet.type(:exec).clear
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "/bin/echo"
            )
        }
        Puppet.type(:exec).clear
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "/bin/echo",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin"
            )
        }
    end

    def test_nonzero_returns
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "mkdir /this/directory/does/not/exist",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 1
            )
        }
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "touch /etc",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 1
            )
        }
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "thiscommanddoesnotexist",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 127
            )
        }
    end

    def test_cwdsettings
        command = nil
        dir = "/tmp"
        wd = Dir.chdir(dir) {
            Dir.getwd
        }
        assert_nothing_raised {
            command = Puppet.type(:exec).create(
                :command => "pwd",
                :cwd => dir,
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 0
            )
        }
        assert_events([:executed_command], command)
        assert_equal(wd,command.output.chomp)
    end

    def test_refreshonly
        file = nil
        cmd = nil
        tmpfile = tempfile()
        @@tmpfiles.push tmpfile
        trans = nil
        File.open(tmpfile, File::WRONLY|File::CREAT|File::TRUNC) { |of|
            of.puts rand(100)
        }
        file = Puppet.type(:file).create(
            :path => tmpfile,
            :checksum => "md5"
        )
        assert_instance_of(Puppet.type(:file), file)
        assert_nothing_raised {
            cmd = Puppet.type(:exec).create(
                :command => "pwd",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :subscribe => [[file.class.name,file.name]],
                :refreshonly => true
            )
        }

        assert_instance_of(Puppet.type(:exec), cmd)

        comp = Puppet.type(:component).create(:name => "RefreshTest")
        [file,cmd].each { |obj|
            comp.push obj
        }
        events = nil
        assert_nothing_raised {
            trans = comp.evaluate
            file.retrieve

            sum = file.state(:checksum)
            assert_equal(sum.is, sum.should)
            events = trans.evaluate.collect { |event|
                event.event
            }
        }
        # the first checksum shouldn't result in a changed file
        assert_equal([],events)
        File.open(tmpfile, File::WRONLY|File::CREAT|File::TRUNC) { |of|
            of.puts rand(100)
            of.puts rand(100)
            of.puts rand(100)
        }
        assert_nothing_raised {
            trans = comp.evaluate
            sum = file.state(:checksum)
            events = trans.evaluate.collect { |event| event.event }
        }
        
        # verify that only the file_changed event was kicked off, not the
        # command_executed
        assert_equal(
            [:file_changed],
            events
        )
    end

    def test_creates
        file = tempfile()
        exec = nil
        assert(! FileTest.exists?(file), "File already exists")
        assert_nothing_raised {
            exec = Puppet.type(:exec).create(
                :command => "touch %s" % file,
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :creates => file
            )
        }

        comp = newcomp("createstest", exec)
        assert_events([:executed_command], comp, "creates")
        assert_events([], comp, "creates")
    end

    # Verify that we can download the file that we're going to execute.
    def test_retrievethenmkexe
        exe = tempfile()
        oexe = tempfile()
        sh = %x{which sh}
        File.open(exe, "w") { |f| f.puts "#!#{sh}\necho yup" }

        file = Puppet.type(:file).create(
            :name => oexe,
            :source => exe,
            :mode => 0755
        )

        exec = Puppet.type(:exec).create(
            :name => oexe,
            :require => [:file, oexe]
        )

        comp = newcomp("Testing", file, exec)

        assert_events([:file_created, :executed_command], comp)
    end

    # Verify that we auto-require any managed scripts.
    def test_autorequire
        exe = tempfile()
        oexe = tempfile()
        sh = %x{which sh}
        File.open(exe, "w") { |f| f.puts "#!#{sh}\necho yup" }

        file = Puppet.type(:file).create(
            :name => oexe,
            :source => exe,
            :mode => 755
        )

        basedir = File.dirname(oexe)
        baseobj = Puppet.type(:file).create(
            :name => basedir,
            :source => exe,
            :mode => 755
        )

        ofile = Puppet.type(:file).create(
            :name => exe,
            :mode => 755
        )

        exec = Puppet.type(:exec).create(
            :name => oexe,
            :path => ENV["PATH"],
            :cwd => basedir
        )

        cat = Puppet.type(:exec).create(
            :name => "cat %s %s" % [exe, oexe],
            :path => ENV["PATH"]
        )

        Puppet::Type.finalize

        # Verify we get the script itself
        assert(exec.requires?(file), "Exec did not autorequire %s" % file)

        # Verify we catch the cwd
        assert(exec.requires?(baseobj), "Exec did not autorequire cwd")

        # Verify we don't require ourselves
        assert(!exec.requires?(ofile), "Exec incorrectly required file")

        # Verify that we catch inline files
        # We not longer autorequire inline files
        assert(! cat.requires?(ofile), "Exec required second inline file")
        assert(! cat.requires?(file), "Exec required inline file")
    end

    def test_ifonly
        afile = tempfile()
        bfile = tempfile()

        exec = nil
        assert_nothing_raised {
            exec = Puppet.type(:exec).create(
                :command => "touch %s" % bfile,
                :onlyif => "test -f %s" % afile,
                :path => ENV['PATH']
            )
        }

        assert_events([], exec)
        system("touch %s" % afile)
        assert_events([:executed_command], exec)
        assert_events([:executed_command], exec)
        system("rm %s" % afile)
        assert_events([], exec)
    end

    def test_unless
        afile = tempfile()
        bfile = tempfile()

        exec = nil
        assert_nothing_raised {
            exec = Puppet.type(:exec).create(
                :command => "touch %s" % bfile,
                :unless => "test -f %s" % afile,
                :path => ENV['PATH']
            )
        }

        assert_events([:executed_command], exec)
        assert_events([:executed_command], exec)
        system("touch %s" % afile)
        assert_events([], exec)
        assert_events([], exec)
        system("rm %s" % afile)
        assert_events([:executed_command], exec)
        assert_events([:executed_command], exec)
    end

    if Process.uid == 0
        # Verify that we can execute commands as a special user
        def mknverify(file, user, group = nil, id = true)
            args = {
                :command => "touch %s" % file,
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
            }

            if user
                #Puppet.warning "Using user %s" % user.name
                if id
                    # convert to a string, because that's what the object expects
                    args[:user] = user.uid.to_s
                else
                    args[:user] = user.name
                end
            end

            if group
                #Puppet.warning "Using group %s" % group.name
                if id
                    args[:group] = group.gid.to_s
                else
                    args[:group] = group.name
                end
            end
            exec = nil
            assert_nothing_raised {
                exec = Puppet.type(:exec).create(args)
            }

            comp = newcomp("usertest", exec)
            assert_events([:executed_command], comp, "usertest")

            assert(FileTest.exists?(file), "File does not exist")
            if user
                assert_equal(user.uid, File.stat(file).uid, "File UIDs do not match")
            end

            # We can't actually test group ownership, unfortunately, because
            # behaviour changes wildlly based on platform.
            Puppet::Type.allclear
        end

        def test_userngroup
            file = tempfile()
            [
                [nonrootuser()], # just user, by name
                [nonrootuser(), nil, true], # user, by uid
                [nil, nonrootgroup()], # just group
                [nil, nonrootgroup(), true], # just group, by id
                [nonrootuser(), nonrootgroup()], # user and group, by name
                [nonrootuser(), nonrootgroup(), true], # user and group, by id
            ].each { |ary|
                mknverify(file, *ary) {
                }
            }
        end
    end

    def test_logoutput
        exec = nil
        assert_nothing_raised {
            exec = Puppet.type(:exec).create(
                :name => "logoutputesting",
                :path => "/usr/bin:/bin",
                :command => "echo logoutput is false",
                :logoutput => false
            )
        }

        assert_apply(exec)

        assert_nothing_raised {
            exec[:command] = "echo logoutput is true"
            exec[:logoutput] = true
        }

        assert_apply(exec)

        assert_nothing_raised {
            exec[:command] = "echo logoutput is warning"
            exec[:logoutput] = "warning"
        }

        assert_apply(exec)
    end

    def test_execthenfile
        exec = nil
        file = nil
        basedir = tempfile()
        path = File.join(basedir, "subfile")
        assert_nothing_raised {
            exec = Puppet.type(:exec).create(
                :name => "mkdir",
                :path => "/usr/bin:/bin",
                :creates => basedir,
                :command => "mkdir %s; touch %s" % [basedir, path]

            )
        }

        assert_nothing_raised {
            file = Puppet.type(:file).create(
                :path => basedir,
                :recurse => true,
                :mode => "755",
                :require => ["exec", "mkdir"]
            )
        }

        Puppet::Type.finalize

        comp = newcomp(file, exec)
        assert_events([:executed_command, :file_changed], comp)

        assert(FileTest.exists?(path), "Exec ran first")
        assert(File.stat(path).mode & 007777 == 0755)
    end
end

# $Id$
