#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'puppettest/support/utils'
require 'puppettest/support/assertions'
require 'puppet/network/client/resource'

class TestResourceClient < Test::Unit::TestCase
    include PuppetTest::ServerTest
    include PuppetTest::Support::Utils

    def mkresourceserver
        Puppet::Network::Handler.resource.new
    end

    def mkclient
        client = Puppet::Network::Client.resource.new(:Resource => mkresourceserver)
    end

    def test_resources
        file = tempfile()
        text = "yayness\n"
        File.open(file, "w") { |f| f.print text }

        mkresourceserver()

        client = mkclient()

        # Test describing
        tobj = nil
        assert_nothing_raised {
            tobj = client.describe("file", file)
        }

        assert(tobj, "Did not get response")

        assert_instance_of(Puppet::TransObject, tobj)

        obj = nil
        assert_nothing_raised {
            obj = tobj.to_type
        }
        assert_events([], obj)
        File.unlink(file)
        assert_events([:file_created], obj)
        File.unlink(file)

        # Now test applying
        result = nil
        assert_nothing_raised {
            result = client.apply(tobj)
        }
        assert(FileTest.exists?(file), "File was not created on apply")

        # Lastly, test "list"
        list = nil
        assert_nothing_raised {
            list = client.list("user")
        }

        assert_instance_of(Puppet::TransBucket, list)

        count = 0
        list.each do |tobj|
            break if count > 3
            assert_instance_of(Puppet::TransObject, tobj)

            tobj2 = nil
            assert_nothing_raised {
                tobj2 = client.describe(tobj.type, tobj.name)
            }

            obj = nil
            assert_nothing_raised {
                obj = tobj2.to_type
            }
            assert_events([], obj)

            count += 1
        end
    end
end

