#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'puppet/network/handler/master'

class TestMaster < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def teardown
        super
        Puppet::Indirector::Indirection.clear_cache
    end

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
        Puppet[:manifest] = manifest
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Network::Handler.master.new(
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

        Puppet.settings.use(:main)
        config = nil
        assert_nothing_raised {
            config = client.getconfig
            config.apply
        }

        # Now it should be up to date
        assert(client.fresh?(facts), "Client is not up to date")

        # Cache this value for later
        parse1 = master.freshness("mynode")

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
        assert_equal(parse1, master.freshness("mynode"), "Master did not wait through timeout")
        assert(client.fresh?(facts), "Client is not up to date")

        # Then eliminate it
        Puppet[:filetimeout] = 0

        # Now make sure the master does reparse
        #Puppet.notice "%s vs %s" % [parse1, master.freshness]
        assert(parse1 != master.freshness("mynode"), "Master did not reparse file")
        assert(! client.fresh?(facts), "Client is incorrectly up to date")

        # Retrieve and apply the new config
        assert_nothing_raised {
            config = client.getconfig
            config.apply
        }
        assert(client.fresh?(facts), "Client is not up to date")

        assert(FileTest.exists?(file2), "Second file %s does not exist" % file2)
    end

    # Make sure we're correctly doing clientname manipulations.
    # Testing to make sure we always get a hostname and IP address.
    def test_clientname
        # create our master
        master = Puppet::Network::Handler.master.new(
            :Manifest => tempfile,
            :UseNodes => true,
            :Local => true
        )


        # First check that 'cert' works
        Puppet[:node_name] = "cert"

        # Make sure we get the fact data back when nothing is set
        facts = {"hostname" => "fact_hostname", "ipaddress" => "fact_ip"}
        certname = "cert_hostname"
        certip = "cert_ip"

        resname, resip = master.send(:clientname, nil, nil, facts)
        assert_equal(facts["hostname"], resname, "Did not use fact hostname when no certname was present")
        assert_equal(facts["ipaddress"], resip, "Did not use fact ip when no certname was present")

        # Now try it with the cert stuff present
        resname, resip = master.send(:clientname, certname, certip, facts)
        assert_equal(certname, resname, "Did not use cert hostname when certname was present")
        assert_equal(certip, resip, "Did not use cert ip when certname was present")

        # And reset the node_name stuff and make sure we use it.
        Puppet[:node_name] = :facter
        resname, resip = master.send(:clientname, certname, certip, facts)
        assert_equal(facts["hostname"], resname, "Did not use fact hostname when nodename was set to facter")
        assert_equal(facts["ipaddress"], resip, "Did not use fact ip when nodename was set to facter")
    end
end


