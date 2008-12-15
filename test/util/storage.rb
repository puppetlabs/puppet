#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppettest'

class TestStorage < Test::Unit::TestCase
	include PuppetTest

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

        # Load first, since that's what we do in the code base; this creates
        # all of the necessary directories.
        assert_nothing_raised {
            Puppet::Util::Storage.load
        }

        hash = {:a => :b, :c => :d}

        state = nil
        assert_nothing_raised {
            state = Puppet::Util::Storage.cache(f)
        }

        assert(!state.include?("name"))

        assert_nothing_raised {
            state["name"] = hash
        }

        assert_nothing_raised {
            Puppet::Util::Storage.store
        }
        assert_nothing_raised {
            Puppet::Util::Storage.clear
        }
        assert_nothing_raised {
            Puppet::Util::Storage.load
        }

        # Reset it
        state = nil
        assert_nothing_raised {
            state = Puppet::Util::Storage.cache(f)
        }

        assert_equal(state["name"], hash)
    end

    def test_emptyrestore
        Puppet::Util::Storage.load
        Puppet::Util::Storage.store
        Puppet::Util::Storage.clear
        Puppet::Util::Storage.load

        f = mkfile()
        state = Puppet::Util::Storage.cache(f)
        assert_same Hash, state.class
        assert_equal 0, state.size
    end
    
    def test_caching
        hash = nil
        one = Puppet::Type.type(:exec).create :title => "/bin/echo one"
        [one, :yayness].each do |object|
            assert_nothing_raised do
                hash = Puppet::Util::Storage.cache(object)
            end
            assert_equal({}, hash, "Did not get empty hash back for %s" % object)
        
            hash[:testing] = true
            assert_nothing_raised do
                hash = Puppet::Util::Storage.cache(object)
            end
            assert_equal({:testing => true}, hash, "Did not get hash back for %s" % object)
        end
        assert_raise(ArgumentError, "was able to cache from string") do
            Puppet::Util::Storage.cache("somethingelse")
        end
    end
end

