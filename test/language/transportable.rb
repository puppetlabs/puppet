#!/usr/bin/ruby

if __FILE__ == $0
    $:.unshift '../../lib'
    $:.unshift '..'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppet/transportable'
require 'test/unit'
require 'puppettest'
require 'yaml'

class TestTransportable < Test::Unit::TestCase
	include TestPuppet

    def mkobj(file = "/etc/passwd")
        obj = nil
        assert_nothing_raised {
            obj = Puppet::TransObject.new("file", file)
            obj["owner"] = "root"
            obj["mode"] = "644"
        }

        return obj
    end

    def mkbucket(*objects)
        bucket = nil
        assert_nothing_raised {
            bucket = Puppet::TransBucket.new
            bucket.name = "yayname"
            bucket.type = "yaytype"
        }

        objects.each { |o| bucket << o }

        return bucket
    end

    def test_yamldumpobject
        obj = mkobj
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
            mkobj(d)
        }
        bucket = mkbucket(*objects)
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
end
