#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/rails'
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
        bucket = mk_transtree do |object, depth, width|
            # and mark some of them collectable
            if width % 2 == 1
                object.collectable = true
            end
        end

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

        host = nil
        assert_nothing_raised {
            host = Puppet::Rails::Host.find_by_name(facts["hostname"])
        }
        assert(host, "Could not find host object")

        assert(host.rails_objects, "No objects on host")

        collectable = host.rails_objects.find_all do |obj| obj.collectable end

        assert(collectable.length > 0, "Found no collectable objects")

        collectable.each do |obj|
            trans = nil
            assert_nothing_raised {
                trans = obj.to_trans
            }
            # Make sure that the objects do not retain their collectable
            # nature.
            assert(!trans.collectable, "Object from db was collectable")
        end

        assert_equal(facts["hostname"], host.facts["hostname"],
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
