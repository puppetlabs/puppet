require 'puppet'
require 'puppet/server'
require 'puppet/client'
require 'puppettest'

class TestMaster < Test::Unit::TestCase
    include PuppetTest::ServerTest
    def teardown
        super
        #print "\n\n\n\n" if Puppet[:debug]
    end

    # run through all of the existing test files and make sure everything
    # works
    def test_files
        count = 0
        textfiles { |file|
            Puppet.debug("parsing %s" % file)
            client = nil
            master = nil

            # create our master
            assert_nothing_raised() {
                # this is the default server setup
                master = Puppet::Server::Master.new(
                    :Manifest => file,
                    :UseNodes => false,
                    :Local => true
                )
            }

            # and our client
            assert_nothing_raised() {
                client = Puppet::Client::MasterClient.new(
                    :Master => master
                )
            }

            # pull our configuration a few times
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }
            assert_nothing_raised() {
                client.getconfig
                stopservices
                Puppet::Type.allclear
            }
            # only test three files; that's plenty
            if count > 3
                break
            end
            count += 1
        }
    end

    def test_defaultmanifest
        textfiles { |file|
            Puppet[:manifest] = file
            client = nil
            master = nil
            assert_nothing_raised() {
                # this is the default server setup
                master = Puppet::Server::Master.new(
                    :Manifest => file,
                    :UseNodes => false,
                    :Local => true
                )
            }
            assert_nothing_raised() {
                client = Puppet::Client::MasterClient.new(
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

        file2 = @createdfile + "2"
        @@tmpfiles << file2

        client = master = nil
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
                :Manifest => manifest,
                :UseNodes => false,
                :Local => true
            )
        }
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Master => master
            )
        }

        # The client doesn't have a config, so it can't be up to date
        assert(! client.fresh?, "Client is incorrectly up to date")

        assert_nothing_raised {
            client.getconfig
            client.apply
        }

        # Now it should be up to date
        assert(client.fresh?, "Client is not up to date")

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
        assert(client.fresh?, "Client is not up to date")

        # Then eliminate it
        Puppet[:filetimeout] = 0

        # Now make sure the master does reparse
        #Puppet.notice "%s vs %s" % [parse1, master.freshness]
        assert(parse1 != master.freshness, "Master did not reparse file")
        assert(! client.fresh?, "Client is incorrectly up to date")

        # Retrieve and apply the new config
        assert_nothing_raised {
            client.getconfig
            client.apply
        }
        assert(client.fresh?, "Client is not up to date")

        assert(FileTest.exists?(file2), "Second file %s does not exist" % file2)
    end

    def test_addfacts
        master = nil
        file = mktestmanifest()
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
                :Manifest => file,
                :UseNodes => false,
                :Local => true
            )
        }

        facts = {}

        assert_nothing_raised {
            master.addfacts(facts)
        }

        %w{serverversion servername serverip}.each do |fact|
            assert(facts.include?(fact), "Fact %s was not set" % fact)
        end
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
        factname = Facter["hostname"].value

        File.open(file, "w") { |f|
            f.puts %{
    node #{certname} { file { "#{file_cert}": ensure => file, mode => 755 } }
    node #{factname} { file { "#{file_fact}": ensure => file, mode => 755 } }
}
        }
        # create our master
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
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

end

# $Id$

