if __FILE__ == $0
    if Dir.getwd =~ /test\/server$/
        Dir.chdir("..")
    end

    $:.unshift '../lib'
    $puppetbase = ".."

end

require 'puppet'
require 'puppet/server/authstore'
require 'test/unit'
require 'puppettest.rb'

class TestAuthStore < Test::Unit::TestCase
	include TestPuppet
    def mkstore
        store = nil
        assert_nothing_raised {
            store = Puppet::Server::AuthStore.new
        }

        return store
    end

    def test_localallow
        store = mkstore

        assert_nothing_raised {
            assert(store.allowed?(nil, nil), "Store disallowed local access")
        }

        assert_raise(Puppet::DevError) {
            store.allowed?("kirby.madstop.com", nil)
        }

        assert_raise(Puppet::DevError) {
            store.allowed?(nil, "192.168.0.1")
        }
    end

    def test_hostnames
        store = mkstore

        %w{
            kirby.madstop.com
            luke.madstop.net
            name-other.madstop.net
        }.each { |name|
            assert_nothing_raised("Failed to store simple name %s" % name) {
                store.allow(name)
            }
            assert(store.allowed?(name, "192.168.0.1"), "Name %s not allowed" % name)
        }

        %w{
            invalid
            ^invalid!
            inval$id
        
        }.each { |pat|
            assert_raise(Puppet::Server::AuthStoreError,
                "name '%s' was allowed" % pat) {
                store.allow(pat)
            }
        }
    end

    def test_domains
        store = mkstore

        assert_nothing_raised("Failed to store domains") {
            store.allow("*.a.very.long.domain.name.com")
            store.allow("*.madstop.com")
            store.allow("*.some-other.net")
            store.allow("*.much.longer.more-other.net")
        }

        %w{
            madstop.com
            culain.madstop.com
            kirby.madstop.com
            funtest.some-other.net
            ya-test.madstop.com
            some.much.much.longer.more-other.net
        }.each { |name|
            assert(store.allowed?(name, "192.168.0.1"), "Host %s not allowed" % name)
        }

        assert_raise(Puppet::Server::AuthStoreError) {
            store.allow("domain.*.com")
        }

        assert(!store.allowed?("very.long.domain.name.com", "1.2.3.4"),
            "Long hostname allowed")

        assert_raise(Puppet::Server::AuthStoreError) {
            store.allow("domain.*.other.com")
        }
    end

    def test_simpleips
        store = mkstore

        %w{
            192.168.0.5
            7.0.48.7
        }.each { |ip|
            assert_nothing_raised("Failed to store IP address %s" % ip) {
                store.allow(ip)
            }

            assert(store.allowed?("hosttest.com", ip), "IP %s not allowed" % ip)
        }

        #assert_raise(Puppet::Server::AuthStoreError) {
        #    store.allow("192.168.674.0")
        #}

        assert_raise(Puppet::Server::AuthStoreError) {
            store.allow("192.168.0")
        }
    end

    def test_ipranges
        store = mkstore

        %w{
            192.168.0.*
            192.168.1.0/24
            192.178.*
            193.179.0.0/8
        }.each { |range|
            assert_nothing_raised("Failed to store IP range %s" % range) {
                store.allow(range)
            }
        }

        %w{
            192.168.0.1
            192.168.1.5
            192.178.0.5
            193.0.0.1
        }.each { |ip|
            assert(store.allowed?("fakename.com", ip), "IP %s is not allowed" % ip)
        }
    end

    def test_iprangedenials
        store = mkstore

        assert_nothing_raised("Failed to store overlapping IP ranges") {
            store.allow("192.168.0.0/16")
            store.deny("192.168.0.0/24")
        }

        assert(store.allowed?("fake.name", "192.168.1.50"), "/16 ip not allowed")
        assert(! store.allowed?("fake.name", "192.168.0.50"), "/24 ip allowed")
    end

    def test_subdomaindenails
        store = mkstore

        assert_nothing_raised("Failed to store overlapping IP ranges") {
            store.allow("*.madstop.com")
            store.deny("*.sub.madstop.com")
        }

        assert(store.allowed?("hostname.madstop.com", "192.168.1.50"),
            "hostname not allowed")
        assert(! store.allowed?("name.sub.madstop.com", "192.168.0.50"),
            "subname name allowed")
    end

    def test_orderingstuff
        store = mkstore

        assert_nothing_raised("Failed to store overlapping IP ranges") {
            store.allow("*.madstop.com")
            store.deny("192.168.0.0/24")
        }

        assert(store.allowed?("hostname.madstop.com", "192.168.1.50"),
            "hostname not allowed")
        assert(! store.allowed?("hostname.madstop.com", "192.168.0.50"),
            "Host allowed over IP")
    end

    def test_globalallow
        store = mkstore

        assert_nothing_raised("Failed to add global allow") {
            store.allow("*")
        }

        [
            %w{hostname.com 192.168.0.4},
            %w{localhost 192.168.0.1},
            %w{localhost 127.0.0.1}
            
        ].each { |ary|
            assert(store.allowed?(*ary), "Failed to allow %s" % [ary.join(",")])
        }
    end

    # Make sure people can specify TLDs
    def test_match_tlds
        store = mkstore

        assert_nothing_raised {
            store.allow("*.tld")
        }
    end
end

# $Id$

