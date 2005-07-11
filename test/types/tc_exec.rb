if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'
require 'facter'

# $Id$

class TestExec < Test::Unit::TestCase
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
    end

    def teardown
        Puppet::Type.allclear
    end

    def test_execution
        command = nil
        output = nil
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "/bin/echo"
            )
        }
        assert_nothing_raised {
            command.retrieve
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
            command = Puppet::Type::Exec.new(
                :command => "/bin/echo",
                :returns => 0
            )
        }
        assert_nothing_raised {
            command.retrieve
        }
        assert_nothing_raised {
            output = command.sync
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "/bin/echo",
                :returns => "0"
            )
        }
        assert_nothing_raised {
            command.retrieve
        }
        assert_nothing_raised {
            output = command.sync
        }
    end

    def test_path_or_qualified
        command = nil
        output = nil
        assert_raise(TypeError) {
            command = Puppet::Type::Exec.new(
                :command => "echo"
            )
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "echo",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin"
            )
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "/bin/echo"
            )
        }
        Puppet::Type::Exec.clear
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "/bin/echo",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin"
            )
        }
    end

    def test_nonzero_returns
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "mkdir /this/directory/does/not/exist",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 1
            )
        }
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "touch /etc",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 1
            )
        }
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "thiscommanddoesnotexist",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 127
            )
        }
    end

    def test_cwdsettings
        command = nil
        assert_nothing_raised {
            command = Puppet::Type::Exec.new(
                :command => "pwd",
                :cwd => "/tmp",
                :path => "/usr/bin:/bin:/usr/sbin:/sbin",
                :returns => 0
            )
        }
        assert_nothing_raised {
            command.retrieve
        }
        assert_nothing_raised {
            command.sync
        }
        assert_equal("/tmp\n",command.output)
    end
end
