#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/parser/parser'
require 'puppet/client'
require 'test/unit'
require 'puppettest'

class TestRails < Test::Unit::TestCase
	include ParserTesting

    def test_includerails
        assert_nothing_raised {
            require 'puppet/rails'
        }
    end

    # Don't do any tests w/out this class
    if defined? ActiveRecord::Base
    def test_hostcache
        # First make some objects
        object = Puppet::TransObject.new("/tmp", "file")
        object.tags = %w{testing puppet}
        object[:mode] = "1777"
        object[:owner] = "root"

        bucket = Puppet::TransBucket.new
        bucket.push object

        # Now collect our facts
        facts = {}
        Facter.each do |fact, value| facts[fact] = value end

        assert_nothing_raised {
            Puppet::Rails.init
        }

        # Now try storing our crap
        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.store(
                :objects => bucket,
                :facts => facts,
                :host => facts["hostname"]
            )
        }

        assert(host, "Did not create host")

        obj = nil
        assert_nothing_raised {
            obj = Puppet::Rails::Host.find_by_name(facts["hostname"])
        }
        assert(obj, "Could not find host object")

        assert(obj.rails_objects, "No objects on host")

        assert_equal(facts["hostname"], obj.facts["hostname"],
            "Did not retrieve facts")
    end

    def test_railsinit
        assert_nothing_raised {
            Puppet::Rails.init
        }

        assert(FileTest.exists?(Puppet[:dblocation]), "Database does not exist")
    end
    else
        $stderr.puts "Install Rails for Rails and Caching tests"
    end
end

# $Id$
