#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestExec < Test::Unit::TestCase
	include PuppetTest
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
        assert_raise(Puppet::Error) {
            command = Puppet.type(:exec).create(
                :command => "echo"
            )
        }
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

    def test_refreshonly_functional
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
                :subscribe => file,
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

            sum = file.property(:checksum)
            assert(sum.insync?, "checksum is not in sync")
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
            sum = file.property(:checksum)
            events = trans.evaluate.collect { |event| event.event }
        }
        
        # verify that only the file_changed event was kicked off, not the
        # command_executed
        assert_equal(
            [:file_changed, :triggered],
            events
        )
    end

    def test_refreshonly
        cmd = true
        assert_nothing_raised {
            cmd = Puppet.type(:exec).create(
                :command => "pwd",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :refreshonly => true
            )
        }

        # Checks should always fail when refreshonly is enabled
        assert(!cmd.check, "Check passed with refreshonly true")

        # Now set it to false
        cmd[:refreshonly] = false
        assert(cmd.check, "Check failed with refreshonly false")
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
            :path => oexe,
            :source => exe,
            :mode => 0755
        )

        exec = Puppet.type(:exec).create(
            :command => oexe,
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
            :path => oexe,
            :source => exe,
            :mode => 755
        )

        basedir = File.dirname(oexe)
        baseobj = Puppet.type(:file).create(
            :path => basedir,
            :source => exe,
            :mode => 755
        )

        ofile = Puppet.type(:file).create(
            :path => exe,
            :mode => 755
        )

        exec = Puppet.type(:exec).create(
            :command => oexe,
            :path => ENV["PATH"],
            :cwd => basedir
        )

        cat = Puppet.type(:exec).create(
            :command => "cat %s %s" % [exe, oexe],
            :path => ENV["PATH"]
        )
        
        rels = nil
        assert_nothing_raised do
            rels = exec.autorequire
        end

        # Verify we get the script itself
        assert(rels.detect { |r| r.source == file }, "Exec did not autorequire its command")

        # Verify we catch the cwd
        assert(rels.detect { |r| r.source == baseobj }, "Exec did not autorequire its cwd")

        # Verify we don't require ourselves
        assert(! rels.detect { |r| r.source == ofile }, "Exec incorrectly required mentioned file")
        assert(!exec.requires?(ofile), "Exec incorrectly required file")

        # We not longer autorequire inline files
        assert_nothing_raised do
            rels = cat.autorequire
        end
        assert(! rels.detect { |r| r.source == ofile }, "Exec required second inline file")
        assert(! rels.detect { |r| r.source == file }, "Exec required inline file")
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
        comp = newcomp(exec)

        assert_events([:executed_command], comp)
        assert_events([:executed_command], comp)
        system("touch %s" % afile)
        assert_events([], comp)
        assert_events([], comp)
        system("rm %s" % afile)
        assert_events([:executed_command], comp)
        assert_events([:executed_command], comp)
    end

    if Puppet::SUIDManager.uid == 0
        # Verify that we can execute commands as a special user
        def mknverify(file, user, group = nil, id = true)
            File.umask(0022)
                
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
                :title => "logoutputesting",
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
                :title => "mkdir",
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

        comp = newcomp(file, exec)
        comp.finalize
        assert_events([:executed_command, :file_changed], comp)

        assert(FileTest.exists?(path), "Exec ran first")
        assert(File.stat(path).mode & 007777 == 0755)
    end

    # Make sure all checks need to be fully qualified.
    def test_falsevals
        exec = nil
        assert_nothing_raised do
            exec = Puppet.type(:exec).create(
                :command => "/bin/touch yayness"
            )
        end

        Puppet.type(:exec).checks.each do |check|
            klass = Puppet.type(:exec).paramclass(check)
            next if klass.values.include? :false
            assert_raise(Puppet::Error, "Check '%s' did not fail on false" % check) do
                exec[check] = false
            end
        end
    end

    def test_createcwdandexe
        exec1 = exec2 = nil
        dir = tempfile()
        file = tempfile()

        assert_nothing_raised {
            exec1 = Puppet.type(:exec).create(
                :title => "one",
                :path => ENV["PATH"],
                :command => "mkdir #{dir}"
            )
        }

        assert_nothing_raised("Could not create exec w/out existing cwd") {
            exec2 = Puppet.type(:exec).create(
                :title => "two",
                :path => ENV["PATH"],
                :command => "touch #{file}",
                :cwd => dir
            )
        }

        # Throw a check in there with our cwd and make sure it works
        assert_nothing_raised("Could not check with a missing cwd") do
            exec2[:unless] = "test -f /this/file/does/not/exist"
            exec2.retrieve
        end

        assert_raise(Puppet::Error) do
            exec2.property(:returns).sync
        end

        assert_nothing_raised do
            exec2[:require] = exec1
        end

        assert_apply(exec1, exec2)

        assert(FileTest.exists?(file))
    end

    def test_checkarrays
        exec = nil
        file = tempfile()

        test = "test -f #{file}"

        assert_nothing_raised {
            exec = Puppet.type(:exec).create(
                :path => ENV["PATH"],
                :command => "touch #{file}"
            )
        }

        assert_nothing_raised {
            exec[:unless] = test
        }

        assert_nothing_raised {
            assert(exec.check, "Check did not pass")
        }

        assert_nothing_raised {
            exec[:unless] = [test, test]
        }


        assert_nothing_raised {
            exec.finish
        }

        assert_nothing_raised {
            assert(exec.check, "Check did not pass")
        }

        assert_apply(exec)

        assert_nothing_raised {
            assert(! exec.check, "Check passed")
        }
    end

    def test_missing_checks_cause_failures
        # Solaris's sh exits with 1 here instead of 127
        return if Facter.value(:operatingsystem) == "Solaris"
        exec = Puppet::Type.newexec(
                                    :command => "echo true",
                                    :path => ENV["PATH"],
                                    :onlyif => "/bin/nosuchthingexists"
                                   )

        assert_raise(ArgumentError, "Missing command did not raise error") {
            exec.run("/bin/nosuchthingexists")
        } 
    end

    def test_envparam
        exec = Puppet::Type.newexec(
            :command => "echo $envtest",
            :path => ENV["PATH"],
            :env => "envtest=yayness"
        )

        assert(exec, "Could not make exec")

        output = status = nil
        assert_nothing_raised {
            output, status = exec.run("echo $envtest")
        }

        assert_equal("yayness\n", output)

        # Now check whether we can do multiline settings
        assert_nothing_raised do
            exec[:env] = "envtest=a list of things
and stuff"
        end

        output = status = nil
        assert_nothing_raised {
            output, status = exec.run('echo "$envtest"')
        }
        assert_equal("a list of things\nand stuff\n", output)

        # Now test arrays
        assert_nothing_raised do
            exec[:env] = ["funtest=A", "yaytest=B"]
        end

        output = status = nil
        assert_nothing_raised {
            output, status = exec.run('echo "$funtest" "$yaytest"')
        }
        assert_equal("A B\n", output)
    end
    
    def test_timeout
        exec = Puppet::Type.type(:exec).create(:command => "sleep 1", :path => ENV["PATH"], :timeout => "0.2")
        time = Time.now
        
        assert_raise(Timeout::Error) {
            exec.run("sleep 1")
        }
        Puppet.info "%s seconds, vs a timeout of %s" % [Time.now.to_f - time.to_f, exec[:timeout]]
        
        
        assert_apply(exec)
    end

    # Testing #470
    def test_run_as_created_user
        exec = nil
        if Process.uid == 0
            user = "nosuchuser"
            assert_nothing_raised("Could not create exec with non-existent user") do
                exec = Puppet::Type.type(:exec).create(
                    :command => "/bin/echo yay",
                    :user => user
                )
            end
        end

        # Now try the group
        group = "nosuchgroup"
        assert_nothing_raised("Could not create exec with non-existent user") do
            exec = Puppet::Type.type(:exec).create(
                :command => "/bin/echo yay",
                :group => group
            )
        end
    end

    # make sure paths work both as arrays and strings
    def test_paths_as_arrays
        path = %w{/usr/bin /usr/sbin /sbin}
        exec = nil
        assert_nothing_raised("Could not use an array for the path") do
            exec = Puppet::Type.type(:exec).create(:command => "echo yay",
                :path => path)
        end
        assert_equal(path, exec[:path], "array-based path did not match")
        assert_nothing_raised("Could not use a string for the path") do
            exec = Puppet::Type.type(:exec).create(:command => "echo yay",
                :path => path.join(":"))
        end
        assert_equal(path, exec[:path], "string-based path did not match")
        assert_nothing_raised("Could not use a colon-separated strings in an array for the path") do
            exec = Puppet::Type.type(:exec).create(:command => "echo yay",
                :path => ["/usr/bin", "/usr/sbin:/sbin"])
        end
        assert_equal(path, exec[:path], "colon-separated array path did not match")
    end

    def test_checks_apply_to_refresh
        file = tempfile()
        maker = tempfile()
        exec = Puppet::Type.type(:exec).create(
            :title => "maker",
            :command => "touch #{maker}",
            :path => ENV["PATH"]
        )

        # Make sure it runs normally
        assert_apply(exec)
        assert(FileTest.exists?(maker), "exec did not run")
        File.unlink(maker)

        # Now make sure it refreshes
        assert_nothing_raised("Failed to refresh exec") do
            exec.refresh
        end
        assert(FileTest.exists?(maker), "exec did not run refresh")
        File.unlink(maker)

        # Now add the checks
        exec[:creates] = file

        # Make sure it runs when the file doesn't exist
        assert_nothing_raised("Failed to refresh exec") do
            exec.refresh
        end
        assert(FileTest.exists?(maker), "exec did not refresh when checks passed")
        File.unlink(maker)

        # Now create the file and make sure it doesn't refresh
        File.open(file, "w") { |f| f.puts "" }
        assert_nothing_raised("Failed to refresh exec") do
            exec.refresh
        end
        assert(! FileTest.exists?(maker), "exec refreshed with failing checks")
    end

    def test_explicit_refresh
        refresher = tempfile()
        maker = tempfile()
        exec = Puppet::Type.type(:exec).create(
            :title => "maker",
            :command => "touch #{maker}",
            :path => ENV["PATH"]
        )

        # Call refresh normally
        assert_nothing_raised do
            exec.refresh
        end

        # Make sure it created the normal file
        assert(FileTest.exists?(maker), "normal refresh did not work")
        File.unlink(maker)

        # Now reset refresh, and make sure it wins
        assert_nothing_raised("Could not set refresh parameter") do
            exec[:refresh] = "touch #{refresher}"
        end
        assert_nothing_raised do
            exec.refresh
        end

        # Make sure it created the normal file
        assert(FileTest.exists?(refresher), "refresh param was ignored")
        assert(! FileTest.exists?(maker), "refresh param also ran command")
    end
end

# $Id$
