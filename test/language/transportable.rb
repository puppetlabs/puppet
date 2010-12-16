#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

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

  # Make sure our 'delve' command is working
  def test_delve
    top = mk_transtree do |object, depth, width|
      object.file = :funtest if width % 2 == 1
    end

    objects = []
    buckets = []
    found = []

    count = 0
    assert_nothing_raised {
      top.delve do |object|
        count += 1
        if object.is_a? Puppet::TransBucket
          buckets << object
        else
          objects << object
          if object.file == :funtest
            found << object
          end
        end
      end
    }

    top.flatten.each do |obj|
      assert(objects.include?(obj), "Missing obj #{obj.type}[#{obj.name}]")
    end


          assert_equal(
        found.length,
      top.flatten.find_all { |o| o.file == :funtest }.length,
        
      "Found incorrect number of objects")
  end
end

