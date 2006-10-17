#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'etc'
require 'puppet/type'
require 'puppettest'
require 'puppettest/fileparsing'
require 'test/unit'

class TestParsedHostProvider < Test::Unit::TestCase
	include PuppetTest
	include PuppetTest::FileParsing

    def setup
        super
        @provider = Puppet.type(:host).provider(:parsed)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        super
    end

    def test_provider_existence
        assert(@provider, "Could not retrieve provider")
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @provider.filetype = Puppet::FileType.filetype(:ram)
    end

    def mkhosthash
        if defined? @hcount
            @hcount += 1
        else
            @hcount = 1
        end

        return {
            :name => "fakehost%s" % @hcount,
            :ip => "192.168.27.%s" % @hcount,
            :alias => ["alias%s" % @hcount]
        }
    end

    def mkhost
        hash = mkhosthash()

        fakemodel = fakemodel(:host, hash[:name])

        host = @provider.new(fakemodel)

        hash.each do |name, val|
            fakemodel[name] = val
        end
        assert(host, "Could not create provider host")

        return host
    end

    # Make sure we convert both directlys correctly using a simple host.
    def test_basic_isomorphism
        hash = {:name => "myhost", :ip => "192.168.43.56", :alias => %w{another host}}

        str = nil
        assert_nothing_raised do
            str = @provider.to_record(hash)
        end

        assert_equal("192.168.43.56\tmyhost\tanother\thost", str)

        newhash = nil
        assert_nothing_raised do
            newhash = @provider.parse(str).shift
        end

        assert_equal(hash, newhash)
    end

    # Make sure parsing gets comments, blanks, and hosts
    def test_blanks_and_comments
        mkfaketype()
        text = %{# comment one

192.168.43.56\tmyhost\tanother\thost
    
# another comment
192.168.43.57\tanotherhost
}

        instances = nil
        assert_nothing_raised do
            instances = @provider.parse(text)
        end

        assert_equal([
            "# comment one",
            "",
            {:name => "myhost", :ip => "192.168.43.56", :alias => %w{another host}},
            "    ",
            "# another comment",
            {:name => "anotherhost", :ip => "192.168.43.57"}
        ], instances)

        assert_nothing_raised do
            @provider.store(instances)
        end
        newtext = nil
        assert_nothing_raised do
            newtext = @provider.fileobj.read
        end

        assert_equal(text, newtext)
    end

    def test_empty_and_absent_hashes_are_not_written
        mkfaketype()

        instances = [
            {:name => "myhost", :ip => "192.168.43.56", :alias => %w{another host}},
            {},
            {:ensure => :absent, :name => "anotherhost", :ip => "192.168.43.57"}
        ]

        assert_nothing_raised do
            newtext = @provider.store(instances)
        end
        newtext = nil
        assert_nothing_raised do
            newtext = @provider.fileobj.read
        end
        text = "192.168.43.56\tmyhost\tanother\thost\n"

        assert_equal(text, newtext)
    end

    def test_simplehost
        mkfaketype
        # Start out with no content.
        assert_nothing_raised {
            assert_equal([], @provider.retrieve)
        }

        # Now create a provider
        host = nil
        assert_nothing_raised {
            host = mkhost
        }

        # Make sure we're still empty
        assert_nothing_raised {
            assert_equal([], @provider.retrieve)
        }

        hash = host.model.to_hash

        # Try storing it
        assert_nothing_raised do
            host.store(hash)
        end

        # Make sure we get the host back
        assert_nothing_raised {
            assert_equal([hash], @provider.retrieve)
        }

        # Remove a single field and make sure it gets tossed
        hash.delete(:alias)

        assert_nothing_raised {
            host.store(hash)
            assert_equal([hash], @provider.retrieve)
        }

        # Make sure it throws up if we remove a required field
        hash.delete(:ip)

        assert_raise(ArgumentError) {
            host.store(hash)
        }

        # Now remove the whole object
        assert_nothing_raised {
            host.store({})
            assert_equal([], @provider.retrieve)
        }
    end

    # Parse our sample data and make sure we regenerate it correctly.
    def test_hostsparse
        fakedata("data/types/hosts").each do |file| fakedataparse(file) end
    end

    # Make sure we can modify the file elsewhere and those modifications will
    # get taken into account.
    def test_modifyingfile
        hostfile = tempfile()
        @provider.path = hostfile

        hosts = []
        3.times {
            h = mkhost()
            hosts << h
        }

        hosts.each do |host|
            host.store
        end

        newhost = mkhost()
        hosts << newhost

        # Now store our new host
        newhost.store()

        # Verify we can retrieve that info
        assert_nothing_raised("Could not retrieve after second write") {
            newhost.hash
        }

        text = @provider.fileobj.read

        instances = @provider.retrieve

        # And verify that we have data for everything
        hosts.each { |host|
            name = host.model[:name]
            assert(text.include?(name), "Host %s is not in file" % name)
            hash = host.hash
            assert(! hash.empty?, "Could not find host %s" % name)
            assert(hash[:ip], "Could not find ip for host %s" % name)
        }
    end
end

# $Id$
