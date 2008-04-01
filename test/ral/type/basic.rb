#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'

class TestBasic < Test::Unit::TestCase
	include PuppetTest

    def setup
        super
        @component = nil
        @configfile = nil
        @command = nil

        assert_nothing_raised() {
            @component = Puppet.type(:component).create(
                :name => "yaytest",
                :type => "testing"
            )
        }

        assert_nothing_raised() {
            @filepath = tempfile()
            @configfile = Puppet.type(:file).create(
                :path => @filepath,
                :ensure => "file",
                :checksum => "md5"
            )
        }
        assert_nothing_raised() {
            @command = Puppet.type(:exec).create(
                :title => "echo",
                :command => "echo yay",
                :path => ENV["PATH"]
            )
        }
        @config = mk_catalog(@component, @configfile, @command)
        @config.add_edge @component, @configfile
        @config.add_edge @component, @command
    end

    def teardown
        super
        stopservices
    end

    def test_values
        [:ensure, :checksum].each do |param|
            prop = @configfile.property(param)
            assert(prop, "got no property for %s" % param)
            assert(prop.value, "got no value for %s" % param)
        end
    end

    def test_name_calls
        [@command, @configfile].each { |obj|
            Puppet.debug "obj is %s" % obj
            assert_nothing_raised(){
                obj.name
            }
        }
    end

    def test_name_equality
        assert_equal(@filepath, @configfile.title)

        assert_equal("echo", @command.title)
    end

    def test_object_retrieval
        [@command, @configfile].each { |obj|
            assert_equal(obj.class[obj.name].object_id, obj.object_id,
                "%s did not match class version" % obj.ref)
        }
    end

    def test_paths
        [@configfile, @command, @component].each { |obj|
            assert_nothing_raised {
                assert_instance_of(String, obj.path)
            }
        }
    end
end
