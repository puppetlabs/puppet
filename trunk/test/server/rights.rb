if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/server/rights'
require 'test/unit'
require 'puppettest.rb'

class TestRights < Test::Unit::TestCase
	include TestPuppet

    def test_rights
        store = nil
        assert_nothing_raised {
            store = Puppet::Server::Rights.new
        }

        assert(store, "Did not create store")

        assert_raise(ArgumentError, "Did not fail on unknown right") {
            store.allowed?(:write, "host.madstop.com", "0.0.0.0")
        }

        assert_nothing_raised {
            store.newright(:write)
        }

        assert(! store.allowed?(:write, "host.madstop.com", "0.0.0.0"),
            "Defaulted to allowing access")

        assert_nothing_raised {
            store[:write].info "This is a log message"
        }
    end
end

# $Id$

