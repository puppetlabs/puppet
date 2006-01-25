if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/config'
require 'puppettest'
require 'test/unit'

class TestConfig < Test::Unit::TestCase
	include TestPuppet

    def mkconfig
        c = nil
        assert_nothing_raised {
            c = Puppet::Config.new
        }
        return c
    end

    def test_addbools
        c = mkconfig

        assert_nothing_raised {
            c.setdefaults(:booltest => true)
        }

        assert(c[:booltest])

        assert_nothing_raised {
            c[:booltest] = false
        }

        assert(! c[:booltest])

        assert_raise(Puppet::Error) {
            c[:booltest] = "yayness"
        }
    end
end

# $Id$
