if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'

# $Id$

class TestStorage < Test::Unit::TestCase
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        Puppet[:statefile] = "/var/tmp/puppetteststate"
    end

    def test_simple
        state = nil
        assert_nothing_raised {
            Puppet::Storage.load
        }
        assert_nothing_raised {
            state = Puppet::Storage.state(Puppet::Type)
        }
        assert(state)
        state["/etc/passwd"] = ["md5","9ebebe0c02445c40b9dc6871b64ee416"]
        assert_nothing_raised {
            Puppet::Storage.store
        }
        assert_nothing_raised {
            Puppet::Storage.load
        }
        assert_equal(
            ["md5","9ebebe0c02445c40b9dc6871b64ee416"],
            Puppet::Storage.state(Puppet::Type)["/etc/passwd"]
        )
    end

    def test_instance
        file = nil
        state = nil
        assert_nothing_raised {
            file = Puppet::Type::PFile.new(
                :path => "/etc/passwd"
            )
        }
        assert_nothing_raised {
            Puppet::Storage.load
        }
        assert_nothing_raised {
            state = Puppet::Storage.state(file)
        }
        assert(state)
    end

    def teardown
        system("rm -f %s" % Puppet[:statefile])
    end
end
