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
        tresource = nil
        assert_nothing_raised {
            tresource = client.describe("file", file)
        }

        assert(tresource, "Did not get response")

        assert_instance_of(Puppet::TransObject, tresource)

        resource = nil
        assert_nothing_raised {
            resource = tresource.to_ral
        }
        assert_events([], resource)
        p resource.instance_variable_get("@stat")
        File.unlink(file)
        assert_events([:file_created], resource)
        File.unlink(file)

        # Now test applying
        result = nil
        assert_nothing_raised {
            result = client.apply(tresource)
        }
        assert(FileTest.exists?(file), "File was not created on apply")

        # Lastly, test "list"
        list = nil
        assert_nothing_raised {
            list = client.list("user")
        }

        assert_instance_of(Puppet::TransBucket, list)

        count = 0
        list.each do |tresource|
            break if count > 3
            assert_instance_of(Puppet::TransObject, tresource)

            tresource2 = nil
            assert_nothing_raised {
                tresource2 = client.describe(tresource.type, tresource.name)
            }

            resource = nil
            assert_nothing_raised {
                resource = tresource2.to_ral
            }
            assert_events([], resource)

            count += 1
        end
    end
end

