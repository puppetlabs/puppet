if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'puppettest'
require 'puppet/storage'
require 'test/unit'

# $Id$

class StorageTestingClass
end

class TestStorage < Test::Unit::TestCase
	include TestPuppet
    def disabled_setup
        Puppet[:loglevel] = :debug if __FILE__ == $0
        Puppet[:checksumfile] = "/var/tmp/puppetteststate"

        @oldconf = Puppet[:puppetconf]
        Puppet[:puppetconf] = "/tmp/storagetesting"
        @oldvar = Puppet[:puppetvar]
        Puppet[:puppetvar] = "/tmp/storagetesting"

        @@tmpfiles << "/tmp/storagetesting"
    end

    def teardown
        #system("rm -f %s" % Puppet[:checksumfile])
        Puppet::Storage.clear

        #Puppet[:puppetconf] = @oldconf
        #Puppet[:puppetvar] = @oldvar
        super
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

        # clear the memory, so we're sure we're hitting the state file
        assert_nothing_raised {
            Puppet::Storage.clear
            Puppet::Storage.init
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
            file = Puppet::Type::PFile.create(
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

    def test_update
        state = Puppet::Storage.state(StorageTestingClass)
        state["testing"] = "yayness"
        Puppet::Storage.store
        assert(FileTest.exists?(Puppet[:checksumfile]))
    end

    def test_hashstorage
        state = Puppet::Storage.state(StorageTestingClass)
        hash = {
            :yay => "boo",
            :rah => "foo"
        }
        state["testing"] = hash
        Puppet::Storage.store
        Puppet::Storage.clear
        Puppet::Storage.init
        Puppet::Storage.load
        state = Puppet::Storage.state(StorageTestingClass)
        assert_equal(hash, state["testing"])
    end
end
