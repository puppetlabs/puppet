#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../lib/puppettest'

require 'etc'
require 'puppettest'
require 'puppettest/fileparsing'
require 'test/unit'

class TestParsedHostProvider < Test::Unit::TestCase
    include PuppetTest
    include PuppetTest::FileParsing

    def setup
        super
        @provider = Puppet::Type.type(:host).provider(:parsed)

        @oldfiletype = @provider.filetype
    end

    def teardown
        Puppet::Util::FileType.filetype(:ram).clear
        @provider.filetype = @oldfiletype
        @provider.clear
        super
    end

    def test_provider_existence
        assert(@provider, "Could not retrieve provider")
    end

    # Here we just create a fake host type that answers to all of the methods
    # but does not modify our actual system.
    def mkfaketype
        @provider.filetype = Puppet::Util::FileType.filetype(:ram)
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
            :host_aliases => ["alias%s" % @hcount],
            :ensure => :present
        }
    end

    def mkhost
        hash = mkhosthash()

        fakeresource = fakeresource(:host, hash[:name])

        host = @provider.new(fakeresource)

        assert(host, "Could not create provider host")
        hash.each do |name, val|
            host.send(name.to_s + "=", val)
        end

        return host
    end

    # Make sure we convert both directlys correctly using a simple host.
    def test_basic_isomorphism
        hash = {:record_type => :parsed, :name => "myhost", :ip => "192.168.43.56", :host_aliases => %w{another host}}

        str = nil
        assert_nothing_raised do
            str = @provider.to_line(hash)
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
            {:record_type => :comment, :line => "# comment one"},
            {:record_type => :blank, :line => ""},
            {:record_type => :parsed, :name => "myhost", :ip => "192.168.43.56", :host_aliases => %w{another host}},
            {:record_type => :blank, :line => "    "},
            {:record_type => :comment, :line => "# another comment"},
            {:record_type => :parsed, :name => "anotherhost", :ip => "192.168.43.57"}
        ], instances)

        newtext = nil
        assert_nothing_raised do
            newtext = @provider.to_file(instances).gsub(/^# HEADER.+\n/, '')
        end

        assert_equal(text, newtext)
    end

    def test_simplehost
        mkfaketype
        @provider.default_target = :yayness
        file = @provider.target_object(:yayness)

        # Start out with no content.
        assert_nothing_raised {
            assert_equal([], @provider.parse(file.read))
        }

        # Now create a provider
        host = nil
        assert_nothing_raised {
            host = mkhost
        }

        # Make sure we're still empty
        assert_nothing_raised {
            assert_equal([], @provider.parse(file.read))
        }

        # Try storing it
        assert_nothing_raised do
            host.flush
        end

        # Make sure we get the host back
        assert_nothing_raised {
            assert(file.read.include?(host.name),
                "Did not flush host to disk")
        }

        # Remove a single field and make sure it gets tossed
        name = host.host_aliases
        host.host_aliases = [:absent]

        assert_nothing_raised {
            host.flush
            assert(! file.read.include?(name[0]),
                "Did not remove host_aliases from disk")
        }

        # Make sure it throws up if we remove a required field
        host.ip = :absent

        assert_raise(ArgumentError) {
            host.flush
        }

        # Now remove the whole object
        host.ensure = :absent
        assert_nothing_raised {
            host.flush
            assert_equal([], @provider.parse(file.read))
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
        @provider.default_target = hostfile

        file = @provider.target_object(hostfile)

        hosts = []
        3.times {
            h = mkhost()
            hosts << h
        }

        hosts.each do |host|
            host.flush
        end

        newhost = mkhost()
        hosts << newhost

        # Now store our new host
        newhost.flush()

        # Verify we can retrieve that info
        assert_nothing_raised("Could not retrieve after second write") {
            @provider.prefetch
        }

        text = file.read

        instances = @provider.parse(text)

        # And verify that we have data for everything
        hosts.each { |host|
            name = host.resource[:name]
            assert(text.include?(name), "Host %s is not in file" % name)
            hash = host.property_hash
            assert(! hash.empty?, "Could not find host %s" % name)
            assert(hash[:ip], "Could not find ip for host %s" % name)
        }
    end
end

