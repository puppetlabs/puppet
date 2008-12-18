#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppettest'

class TestStorage < Test::Unit::TestCase
	include PuppetTest

    def mkfile
        path = tempfile()
        File.open(path, "w") { |f| f.puts :yayness }

        f = Puppet::Type.type(:file).new(
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
                        Puppet::Util::Storage.load
                        state = Puppet::Util::Storage.cache(f)
                        value.each { |k,v| state[k] = v }
                        state[:e] = rand(100)
                        Puppet::Util::Storage.store
                    }
                }
            }
        }
        threads.each { |th| th.join }
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
        one = Puppet::Type.type(:exec).new :title => "/bin/echo one"
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

