if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppettest'
require 'puppet'
require 'test/unit'
require 'facter'

class TestNameServiceProvider < Test::Unit::TestCase
	include FileTesting

    def test_option
        klass = Class.new(Puppet::Type::Provider::NameService)
        klass.model = Puppet::Type.type(:user)

        val = nil
        assert_nothing_raised {
            val = klass.option(:home, :flag)
        }

        assert_nil(val, "Got an option")

        assert_nothing_raised {
            klass.options :home, :flag => "-d"
        }
        assert_nothing_raised {
            val = klass.option(:home, :flag)
        }
        assert_equal("-d", val, "Got incorrect option")
    end
end

# $Id$
