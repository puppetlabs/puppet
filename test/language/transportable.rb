#!/usr/bin/ruby

require 'puppet'
require 'puppet/transportable'
require 'puppettest'
require 'puppettest/parsertesting'
require 'yaml'

class TestTransportable < Test::Unit::TestCase
    include PuppetTest::ParserTesting

    def test_yamldumpobject
        obj = mk_transobject
        obj.to_yaml_properties
        str = nil
        assert_nothing_raised {
            str = YAML.dump(obj)
        }

        newobj = nil
        assert_nothing_raised {
            newobj = YAML.load(str)
        }

        assert(newobj.name, "Object has no name")
        assert(newobj.type, "Object has no type")
    end

    def test_yamldumpbucket
        objects = %w{/etc/passwd /etc /tmp /var /dev}.collect { |d|
            mk_transobject(d)
        }
        bucket = mk_transbucket(*objects)
        str = nil
        assert_nothing_raised {
            str = YAML.dump(bucket)
        }

        newobj = nil
        assert_nothing_raised {
            newobj = YAML.load(str)
        }

        assert(newobj.name, "Bucket has no name")
        assert(newobj.type, "Bucket has no type")
    end

    # Verify that we correctly strip out collectable objects, since they should
    # not be sent to the client.
    def test_collectstrip
        top = mk_transtree do |object, depth, width|
            if width % 2 == 1
                object.collectable = true
            end
        end

        assert(top.flatten.find_all { |o| o.collectable }.length > 0,
            "Could not find any collectable objects")

        # Now strip out the collectable objects
        top.collectstrip!

        # And make sure they're actually gone
        assert_equal(0, top.flatten.find_all { |o| o.collectable }.length,
            "Still found collectable objects")
    end

    # Make sure our 'delve' command is working
    def test_delve
        top = mk_transtree do |object, depth, width|
            if width % 2 == 1
                object.collectable = true
            end
        end

        objects = []
        buckets = []
        collectable = []

        count = 0
        assert_nothing_raised {
            top.delve do |object|
                count += 1
                if object.is_a? Puppet::TransBucket
                    buckets << object
                else
                    objects << object
                    if object.collectable
                        collectable << object
                    end
                end
            end
        }

        top.flatten.each do |obj|
            assert(objects.include?(obj), "Missing obj %s[%s]" % [obj.type, obj.name])
        end

        assert_equal(collectable.length,
            top.flatten.find_all { |o| o.collectable }.length,
            "Found incorrect number of collectable objects")
    end
end

# $Id$
