if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestParsedFile < Test::Unit::TestCase
	include TestPuppet

    def test_storeandretrieve
        hash = {:a => :b, :c => :d}

        state = nil
        assert_nothing_raised {
            state = Puppet::Storage.state(hash)
        }

        assert(!state.include?("name"))

        assert_nothing_raised {
            state["name"] = hash
        }

        assert_nothing_raised {
            Puppet::Storage.store
        }
        assert_nothing_raised {
            state = Puppet::Storage.state(hash)
        }

        assert_equal(state["name"], hash)
    end
end

# $Id$
