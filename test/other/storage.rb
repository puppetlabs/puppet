if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestStorage < Test::Unit::TestCase
	include TestPuppet

    def mkfile
        path = tempfile()
        File.open(path, "w") { |f| f.puts :yayness }

        f = Puppet.type(:file).create(
            :name => path,
            :check => %w{checksum type}
        )

        return f
    end

    def test_storeandretrieve
        path = tempfile()

        f = mkfile()

        hash = {:a => :b, :c => :d}

        state = nil
        assert_nothing_raised {
            state = Puppet::Storage.cache(f)
        }

        assert(!state.include?("name"))

        assert_nothing_raised {
            state["name"] = hash
        }

        assert_nothing_raised {
            Puppet::Storage.store
        }
        assert_nothing_raised {
            Puppet::Storage.clear
        }
        assert_nothing_raised {
            Puppet::Storage.load
        }

        # Reset it
        state = nil
        assert_nothing_raised {
            state = Puppet::Storage.cache(f)
        }

        assert_equal(state["name"], hash)
    end

    # we're getting corrupt files, probably because multiple processes
    # are reading or writing the file at once
    # so we need to test that
    def test_multiwrite
        f = mkfile()

        value = {:a => :b}
        threads = []
        9.times { |a|
            threads << Thread.new {
                9.times { |b|
                    assert_nothing_raised {
                        Puppet::Storage.load
                        state = Puppet::Storage.cache(f)
                        value.each { |k,v| state[k] = v }
                        state[:e] = rand(100)
                        Puppet::Storage.store
                    }
                }
            }
        }
        threads.each { |th| th.join }
    end

    def test_emptyrestore
        Puppet::Storage.load
        Puppet::Storage.store
        Puppet::Storage.clear
        Puppet::Storage.load

        f = mkfile()
        state = Puppet::Storage.cache(f)
        assert_same Hash, state.class
        assert_equal 0, state.size
    end
end

# $Id$
