#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/client/pelement'
require 'puppet/server'
require 'puppettest'

# $Id$

class TestPElementClient < Test::Unit::TestCase
    include PuppetTest::ServerTest

    def mkpelementserver
        handlers = {
            :CA => {}, # so that certs autogenerate
            :PElement => {},
        }

        return mkserver(handlers)
    end

    def mkclient
        client = nil
        assert_nothing_raised {
            client = Puppet::Client::PElement.new(:Server => "localhost",
                :Port => @@port)
        }

        return client
    end

    def test_pelements
        file = tempfile()
        text = "yayness\n"
        File.open(file, "w") { |f| f.print text }

        mkpelementserver()

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
