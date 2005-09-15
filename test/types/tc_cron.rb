if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppettest'
require 'puppet'
require 'puppet/type/cron'
require 'test/unit'
require 'facter'

# $Id$

class TestExec < TestPuppet
    def setup
        @me = %x{whoami}.chomp
        assert(@me != "", "Could not retrieve user name")
        super
    end

    def test_load
        assert_nothing_raised {
            Puppet::Type::Cron.retrieve(@me)
        }
    end
end
