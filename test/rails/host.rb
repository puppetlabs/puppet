#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/puppettest'

require 'puppet'
require 'puppet/rails'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'
require 'puppettest/railstesting'

class TestRailsHost < PuppetTest::TestCase
    confine "Missing ActiveRecord" => Puppet.features.rails?
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::RailsTesting

    def setup
        super
        railsinit if Puppet.features.rails?
    end

    def teardown
        railsteardown if Puppet.features.rails?
        super
    end

    def test_includerails
        assert_nothing_raised {
            require 'puppet/rails'
        }
    end

    def test_store
        @scope = mkscope
        # First make some objects
        resources = []
        4.times { |i|
            # Make a file
            resources << mkresource(:type => "file",
                :title => "/tmp/file#{i.to_s}",
                :params => {:owner => "user#{i}"})

            # And an exec, so we're checking multiple types
            resources << mkresource(:type => "exec",
                :title => "/bin/echo file#{i.to_s}",
                :params => {:user => "user#{i}"})
        }

        # Now collect our facts
        facts = {"hostname" => "myhost", "test1" => "funtest", "ipaddress" => "192.168.0.1"}

        # Now try storing our crap
        host = nil
        node = mknode(facts["hostname"])
        node.parameters = facts
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(node, resources)
        }

        assert(host, "Did not create host")

        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.find_by_name(facts["hostname"])
        }
        assert(host, "Could not find host object")

        assert(host.resources, "No objects on host")

        facts.each do |fact, value|
            assert_equal(value, host.fact(fact)[0].value, "fact %s is wrong" % fact)
        end
        assert_equal(facts["ipaddress"], host.ip, "IP did not get set")

        count = 0
        host.resources.each do |resource|
            assert_equal(host, resource.host)
            count += 1
            i = nil
            if resource[:title] =~ /file([0-9]+)/
                i = $1
            else
                raise "Got weird resource %s" % resource.inspect
            end
            assert(resource[:restype] != "", "Did not get a type from the resource")
            case resource["restype"]
            when "File":
                assert_equal("user#{i}", resource.parameter("owner"),
                    "got no owner for %s" % resource.ref)
            when "Exec":
                assert_equal("user#{i}", resource.parameter("user"),
                    "got no user for %s" % resource.ref)
            else
                raise "Unknown type %s" % resource[:restype].inspect
            end
        end

        assert_equal(8, count, "Did not get enough resources")

        # Now remove a couple of resources
        resources.reject! { |r| r.title =~ /file3/ }

        # Change a few resources
        resources.find_all { |r| r.title =~ /file2/ }.each do |r|
            r.send(:set_parameter, "loglevel", "notice")
        end

        # And add a new resource
        resources << mkresource(:type => "file",
            :title => "/tmp/file_added",
            :params => {:owner => "user_added"})

        # And change some facts
        facts["test2"] = "yaytest"
        facts["test3"] = "funtest"
        facts["test1"] = "changedfact"
        facts.delete("ipaddress")
        node = mknode(facts["hostname"])
        node.parameters = facts
        newhost = nil
        assert_nothing_raised {
            newhost = Puppet::Rails::Host.store(node, resources)
        }

        assert_equal(host.id, newhost.id, "Created new host instance)")

        # Make sure it sets the last_compile time
        assert_nothing_raised do
            assert_instance_of(Time, host.last_compile, "did not set last_compile")
        end

        assert_equal(0, host.fact('ipaddress').size, "removed fact was not deleted")
        facts.each do |fact, value|
            assert_equal(value, host.fact(fact)[0].value, "fact %s is wrong" % fact)
        end

        # And check the changes we made.
        assert(! host.resources.find(:all).detect { |r| r.title =~ /file3/ },
            "Removed resources are still present")

        res = host.resources.find_by_title("/tmp/file_added")
        assert(res, "New resource was not added")
        assert_equal("user_added", res.parameter("owner"), "user info was not stored")

        host.resources.find(:all, :conditions => [ "title like ?", "%file2%"]).each do |r|
            assert_equal("notice", r.parameter("loglevel"),
                "loglevel was not added")
        end
    end
end
