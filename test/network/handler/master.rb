#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppet/network/handler/master'

class TestMaster < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def teardown
        super
        Puppet::Indirector::Indirection.clear_cache
    end

    # Make sure that files are reread when they change.
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

        config = master.getconfig({"hostname" => "blah"})

        # Cache this value for later
        parse1 = master.freshness("mynode")

        sleep 1.5
        # Create a new manifest
        File.open(manifest, "w") { |f|
            f.puts "file { \"%s\": ensure => file }\n" % file2
        }

        # Verify that the master doesn't immediately reparse the file; we
        # want to wait through the timeout
        assert_equal(parse1, master.freshness("mynode"), "Master did not wait through timeout")

        # Then eliminate it
        Puppet[:filetimeout] = 0

        # Now make sure the master does reparse
        #Puppet.notice "%s vs %s" % [parse1, master.freshness]
        assert(parse1 != master.freshness("mynode"), "Master did not reparse file")

        assert(master.getconfig({"hostname" => "blah"}) != config, "Did not use reloaded config")
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
        facts = {
            "hostname" => "fact_hostname",
            "domain" => "fact_domain",
            "fqdn" => "fact_hostname.fact_domain",
            "ipaddress" => "fact_ip"
        }
        certhostname = "cert_hostname"
        certdomain = "cert_domain"
        certname = certhostname + "." + certdomain
        certip = "cert_ip"

        resname, resip = master.send(:clientname, nil, nil, facts)
        assert_equal(facts["hostname"], resname, "Did not use fact hostname when no certname was present")
        assert_equal(facts["ipaddress"], resip, "Did not use fact ip when no certname was present")
        assert_equal(facts["domain"], "fact_domain", "Did not use fact domain when no certname was present")
        assert_equal(facts["fqdn"], "fact_hostname.fact_domain", "Did not use fact fqdn when no certname was present")

        # Now try it with the cert stuff present
        resname, resip = master.send(:clientname, certname, certip, facts)
        assert_equal(certname, resname, "Did not use cert hostname when certname was present")
        assert_equal(certip, resip, "Did not use cert ip when certname was present")
        assert_equal(facts["domain"], certdomain, "Did not use cert domain when certname was present")
        assert_equal(facts["fqdn"], certname, "Did not use cert fqdn when certname was present")

        # And reset the node_name stuff and make sure we use it.
        Puppet[:node_name] = :facter
        resname, resip = master.send(:clientname, certname, certip, facts)
        assert_equal(facts["hostname"], resname, "Did not use fact hostname when nodename was set to facter")
        assert_equal(facts["ipaddress"], resip, "Did not use fact ip when nodename was set to facter")
    end
end


