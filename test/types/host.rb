# Test host job creation, modification, and destruction

if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

class TestHost < Test::Unit::TestCase
	include TestPuppet
    def setup
        super
        # god i'm lazy
        @hosttype = Puppet.type(:host)
        @oldhosttype = @hosttype.filetype
    end

    def teardown
        @hosttype.filetype = @oldhosttype
        Puppet.type(:file).clear
        super
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @hosttype.filetype = Puppet::FileType.filetype(:ram)
    end

    def test_simplehost
        mkfaketype
        host = nil
        assert_nothing_raised {
            assert_nil(Puppet.type(:host).retrieve)
        }

        assert_nothing_raised {
            host = Puppet.type(:host).create(
                :name => "culain",
                :ip => "192.168.0.3"
            )
        }

        assert_nothing_raised {
            Puppet.type(:host).store
        }

        assert_nothing_raised {
            assert_equal(Puppet.type(:host).fileobj.read, Puppet.type(:host).to_file)
        }
    end

    def test_hostsparse
        assert_nothing_raised {
            Puppet.type(:host).retrieve
        }
    end
end

# $Id$
