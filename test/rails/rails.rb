#!/usr/bin/ruby

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

    def test_includerails
        assert_nothing_raised {
            require 'puppet/rails'
        }
    end

    # Don't do any tests w/out this class
    if defined? ActiveRecord::Base
    def test_hostcache
        @interp, @scope, @source = mkclassframing
        # First make some objects
        resources = []
        20.times { |i|
            resources << mkresource(:type => "file", :title => "/tmp/file#{i.to_s}",
                :params => {:owner => "user#{i}"})
        }

        # Now collect our facts
        facts = Facter.to_hash

        assert_nothing_raised {
            Puppet::Rails.init
        }

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

        assert(host.rails_resources, "No objects on host")

        assert_equal(facts["hostname"], host.facts["hostname"],
            "Did not retrieve facts")

        count = 0
        host.rails_resources.each do |resource|
            count += 1
            i = nil
            if resource[:title] =~ /file([0-9]+)/
                i = $1
            else
                raise "Got weird resource %s" % resource.inspect
            end

            assert_equal("user#{i}",
                resource.rails_parameters.find_by_name("owner")[:value])
        end

        assert_equal(20, count, "Did not get enough resources")
    end
    else
        $stderr.puts "Install Rails for Rails and Caching tests"
    end
end

# $Id$
