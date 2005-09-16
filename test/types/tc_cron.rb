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
        id = %x{id}.chomp
        if id =~ /uid=\d+\(([^\)]+)\)/
            @me = $1
        else
            puts id
        end
        unless defined? @me
            raise "Could not retrieve user name; 'id' did not work"
        end
        super
    end

    def test_load
        assert_nothing_raised {
            Puppet::Type::Cron.retrieve(@me)
        }
    end

    def test_mkcron
        cron = nil
        assert_nothing_raised {
            cron = Puppet::Type::Cron.create(
                :command => "date > %s/crontest" % tmpdir(),
                :name => "testcron",
                :user => @me
            )
        }

        comp = newcomp("crontest", cron)

        trans = assert_events(comp, [:cron_created], "crontest")
    end
end
