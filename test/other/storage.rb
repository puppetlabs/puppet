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

    # we're getting corrupt files, probably because multiple processes
    # are reading or writing the file at once
    # so we need to test that
    def test_multiwrite
        value = {:a => :b, :c => :d}
        threads = []
        9.times { |a|
            threads << Thread.new {
                9.times { |b|
                    assert_nothing_raised {
                        Puppet::Storage.load
                        state = Puppet::Storage.state(value)
                        state[:e] = rand(100)
                        Puppet::Storage.store
                    }
                }
            }
        }
        threads.each { |th| th.join }
    end
end

# $Id$
