#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/rails'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'puppettest'
require 'puppettest/parsertesting'
require 'puppettest/resourcetesting'
require 'puppettest/railstesting'

class TestRails < Test::Unit::TestCase
    include PuppetTest::ParserTesting
    include PuppetTest::ResourceTesting
    include PuppetTest::RailsTesting

    def setup
        super
        railsinit
    end

    def teardown
        railsteardown
        super
    end

    def test_includerails
        assert_nothing_raised {
            require 'puppet/rails'
        }
    end

    # Don't do any tests w/out this class
    if Puppet.features.rails?
    def test_hostcache
        @interp, @scope, @source = mkclassframing
        # First make some objects
        resources = []
        10.times { |i|
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
        facts = {"hostname" => Facter.value(:hostname), "test1" => "funtest"}

        # Now try storing our crap
        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(
                :resources => resources,
                :facts => facts,
                :name => facts["hostname"],
                :classes => ["one", "two::three", "four"]
            )
        }

        assert(host, "Did not create host")

        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.find_by_name(facts["hostname"])
        }
        assert(host, "Could not find host object")

        assert(host.resources, "No objects on host")

        assert_equal(facts["hostname"], host.facts("hostname"),
            "Did not retrieve facts")

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
            when "file":
                assert_equal("user#{i}", resource.parameter("owner"),
                    "got no owner for %s" % resource.ref)
            when "exec":
                assert_equal("user#{i}", resource.parameter("user"),
                    "got no user for %s" % resource.ref)
            else
                raise "Unknown type %s" % resource[:restype].inspect
            end
        end

        assert_equal(20, count, "Did not get enough resources")

        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(
                :resources => resources,
                :facts => facts,
                :name => facts["hostname"],
                :classes => ["one", "two::three", "four"]
            )
        }
    end
    else
        $stderr.puts "Install Rails for Rails and Caching tests"
    end
end

# $Id$
