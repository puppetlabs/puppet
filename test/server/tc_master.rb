if __FILE__ == $0
    if Dir.getwd =~ /test\/server$/
        Dir.chdir("..")
    end

    $:.unshift '../lib'
    $puppetbase = ".."

end

require 'puppet'
require 'puppet/server'
require 'puppet/client'
require 'test/unit'
require 'puppettest.rb'

class TestMaster < ServerTest
    def teardown
        super
        print "\n\n\n\n" if Puppet[:debug]
    end

    # run through all of the existing test files and make sure everything
    # works
    def test_files
        count = 0
        textfiles { |file|
            Puppet.err :mark
            Puppet.debug("parsing %s" % file)
            client = nil
            master = nil

            # create our master
            assert_nothing_raised() {
                # this is the default server setup
                master = Puppet::Server::Master.new(
                    :File => file,
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
                    :File => file,
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
        manifest = mktestmanifest()

        file2 = @createdfile + "2"

        client = master = nil
        assert_nothing_raised() {
            # this is the default server setup
            master = Puppet::Server::Master.new(
                :File => manifest,
                :UseNodes => false,
                :Local => true,
                :FileTimeout => 0.5
            )
        }
        assert_nothing_raised() {
            client = Puppet::Client::MasterClient.new(
                :Master => master
            )
        }

        assert_nothing_raised {
            client.getconfig
            client.apply
        }

        assert(FileTest.exists?(@createdfile),
            "Created file %s does not exist" % @createdfile)
        sleep 1
        Puppet::Type.allclear

        File.open(manifest, "w") { |f|
            f.puts "file { \"%s\": create => true }\n" % file2
        }
        assert_nothing_raised {
            client.getconfig
            client.apply
        }

        assert(FileTest.exists?(file2), "Second file %s does not exist" % file2)
    end

end

# $Id$

