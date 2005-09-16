if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'
require 'facter'

# $Id$

class TestExec < TestPuppet
    def test_execution
        command = nil
        output = nil
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "/bin/echo"
            )
        }
        assert_nothing_raised {
            command.evaluate
        }
        assert_nothing_raised {
            output = command.sync
        }
        assert_equal([:executed_command],output)
    end

    def test_numvsstring
        command = nil
        output = nil
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "/bin/echo",
                :returns => 0
            )
        }
        assert_nothing_raised {
            command.evaluate
        }
        assert_nothing_raised {
            output = command.sync
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "/bin/echo",
                :returns => "0"
            )
        }
        assert_nothing_raised {
            command.evaluate
        }
        assert_nothing_raised {
            output = command.sync
        }
    end

    def test_path_or_qualified
        command = nil
        output = nil
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "echo"
            )
            assert_nil(command)
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "echo",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin"
            )
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "/bin/echo"
            )
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "/bin/echo",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin"
            )
        }
    end

    def test_nonzero_returns
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "mkdir /this/directory/does/not/exist",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 1
            )
        }
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
                :command => "touch /etc",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 1
            )
        }
        assert_nothing_raised {
            command = Puppet::Type::Exec.create(
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
            command = Puppet::Type::Exec.create(
                :command => "pwd",
                :cwd => dir,
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 0
            )
        }
        assert_nothing_raised {
            command.evaluate
        }
        assert_nothing_raised {
            command.sync
        }
        assert_equal(wd,command.output.chomp)
    end

    def test_refreshonly
        file = nil
        cmd = nil
        tmpfile = "/tmp/exectesting"
        @@tmpfiles.push tmpfile
        trans = nil
        File.open(tmpfile, File::WRONLY|File::CREAT|File::TRUNC) { |of|
            of.puts rand(100)
        }
        file = Puppet::Type::PFile.create(
            :path => tmpfile,
            :checksum => "md5"
        )
        assert_nothing_raised {
            cmd = Puppet::Type::Exec.create(
                :command => "pwd",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :subscribe => [[file.class.name,file.name]],
                :refreshonly => true
            )
        }

        comp = Puppet::Type::Component.create(:name => "RefreshTest")
        [file,cmd].each { |obj|
            comp.push obj
        }
        events = nil
        assert_nothing_raised {
            trans = comp.evaluate

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
            [:file_modified],
            events
        )
    end

    def test_creates
        file = tempfile()
        exec = nil
        assert_nothing_raised {
            exec = Puppet::Type::Exec.create(
                :command => "touch %s" % file,
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :creates => file
            )
        }

        comp = newcomp("createstest", exec)
        assert_events(comp, [:executed_command], "creates")
        assert_events(comp, [], "creates")
    end
end
