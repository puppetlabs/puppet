#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/handler/master'

class TestMaster < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def test_defaultmanifest
        textfiles { |file|
            Puppet[:manifest] = file
            client = nil
            master = nil
            assert_nothing_raised() {
                # this is the default server setup
                master = Puppet::Network::Handler.master.new(
                    :Manifest => file,
                    :UseNodes => false,
                    :Local => true
                )
            }
            assert_nothing_raised() {
                client = Puppet::Network::Client.master.new(
                    :Master => master
                )
            }

            # pull our configuration
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }

            break
        }
    end

    def test_filereread
        # Start with a normal setting
        Puppet[:filetimeout] = 15
        manifest = mktestmanifest()

        facts = Puppet::Network::Client.master.facts
        # Store them, so we don't determine frshness based on facts.
        Puppet::Util::Storage.cache(:configuration)[:facts] = facts

        file2 = @createdfile + "2"
        @@tmpfiles << file2

        client = master = nil
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Network::Handler.master.new(
                :Manifest => manifest,
                :UseNodes => false,
                :Local => true
            )
        }
        assert_nothing_raised() {
            client = Puppet::Network::Client.master.new(
                :Master => master
            )
        }

        assert(client, "did not create master client")
        # The client doesn't have a config, so it can't be up to date
        assert(! client.fresh?(facts),
            "Client is incorrectly up to date")

        Puppet.config.use(:main)
        assert_nothing_raised {
            client.getconfig
            client.apply
        }

        # Now it should be up to date
        assert(client.fresh?(facts), "Client is not up to date")

        # Cache this value for later
        parse1 = master.freshness

        # Verify the config got applied
        assert(FileTest.exists?(@createdfile),
            "Created file %s does not exist" % @createdfile)
        Puppet::Type.allclear

        sleep 1.5
        # Create a new manifest
        File.open(manifest, "w") { |f|
            f.puts "file { \"%s\": ensure => file }\n" % file2
        }

        # Verify that the master doesn't immediately reparse the file; we
        # want to wait through the timeout
        assert_equal(parse1, master.freshness, "Master did not wait through timeout")
        assert(client.fresh?(facts), "Client is not up to date")

        # Then eliminate it
        Puppet[:filetimeout] = 0

        # Now make sure the master does reparse
        #Puppet.notice "%s vs %s" % [parse1, master.freshness]
        assert(parse1 != master.freshness, "Master did not reparse file")
        assert(! client.fresh?(facts), "Client is incorrectly up to date")

        # Retrieve and apply the new config
        assert_nothing_raised {
            client.getconfig
            client.apply
        }
        assert(client.fresh?(facts), "Client is not up to date")

        assert(FileTest.exists?(file2), "Second file %s does not exist" % file2)
    end

    # Make sure we're using the hostname as configured with :node_name
    def test_hostname_in_getconfig
        master = nil
        file = tempfile()
        #@createdfile = File.join(tmpdir(), self.class.to_s + "manifesttesting" +
        #    "_" + @method_name)
        file_cert = tempfile()
        file_fact = tempfile()

        certname = "y4yn3ss"
        factname = Facter.value("hostname")

        File.open(file, "w") { |f|
            f.puts %{
    node #{certname} { file { "#{file_cert}": ensure => file, mode => 755 } }
    node #{factname} { file { "#{file_fact}": ensure => file, mode => 755 } }
}
        }
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Network::Handler.master.new(
                :Manifest => file,
                :UseNodes => true,
                :Local => true
            )
        }

        result = nil

        # Use the hostname from facter
        Puppet[:node_name] = 'facter'
        assert_nothing_raised {
            result = master.getconfig({"hostname" => factname}, "yaml", certname, "127.0.0.1")
        }

        result = result.flatten

        assert(result.find { |obj| obj.name == file_fact },
            "Could not find correct file")
        assert(!result.find { |obj| obj.name == file_cert },
            "Found incorrect file")

        # Use the hostname from the cert
        Puppet[:node_name] = 'cert'
        assert_nothing_raised {
            result = master.getconfig({"hostname" => factname}, "yaml", certname, "127.0.0.1")
        }

        result = result.flatten

        assert(!result.find { |obj| obj.name == file_fact },
            "Could not find correct file")
        assert(result.find { |obj| obj.name == file_cert },
            "Found incorrect file")
    end

    # Make sure we're correctly doing clientname manipulations.
    # Testing to make sure we always get a hostname and IP address.
    def test_clientname
        master = nil
        file = tempfile()

        File.open(file, "w") { |f|
            f.puts %{
    node yay { file { "/something": ensure => file, mode => 755 } }
}
        }
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Network::Handler.master.new(
                :Manifest => file,
                :UseNodes => true,
                :Local => true
            )
        }

        Puppet[:node_name] = "cert"
        # First act like we're local
        fakename = nil
        fakeip = nil

        name = ip = nil
        facts = Facter.to_hash
        assert_nothing_raised do
            name, ip = master.clientname(fakename, fakeip, facts)
        end

        assert(facts["hostname"], "Removed hostname fact")
        assert(facts["ipaddress"], "Removed ipaddress fact")

        assert_equal(facts["hostname"], name)
        assert_equal(facts["ipaddress"], ip)

        # Now set them to something real, and make sure we get them back
        fakename = "yayness"
        fakeip = "192.168.0.1"
        facts = Facter.to_hash
        assert_nothing_raised do
            name, ip = master.clientname(fakename, fakeip, facts)
        end

        assert(facts["hostname"], "Removed hostname fact")
        assert(facts["ipaddress"], "Removed ipaddress fact")

        assert_equal(fakename, name)
        assert_equal(fakeip, ip)
    end
end

# $Id$

