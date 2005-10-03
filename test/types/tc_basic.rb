if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

class TestBasic < Test::Unit::TestCase
	include TestPuppet
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        super
        @component = nil
        @configfile = nil
        @sleeper = nil

        Puppet[:loglevel] = :debug if __FILE__ == $0

        assert_nothing_raised() {
            @component = Puppet::Type::Component.create(
                :name => "yaytest",
                :type => "testing"
            )
        }

        assert_nothing_raised() {
            @filepath = "/tmp/testfile"
            @@tmpfiles << @filepath
            @configfile = Puppet::Type::PFile.create(
                :path => @filepath,
                :create => true,
                :checksum => "md5"
            )
        }
        assert_nothing_raised() {
            @sleeper = Puppet::Type::Service.create(
                :name => "sleeper",
                :path => File.join($puppetbase,"examples/root/etc/init.d"),
                :hasstatus => true,
                :running => 1
            )
        }
        assert_nothing_raised() {
            @component.push(
                @configfile,
                @sleeper
            )
        }
        
        #puts "Component is %s, id %s" % [@component, @component.object_id]
        #puts "ConfigFile is %s, id %s" % [@configfile, @configfile.object_id]
    end

    def test_name_calls
        [@sleeper,@configfile].each { |obj|
            Puppet.debug "obj is %s" % obj
            assert_nothing_raised(){
                obj.name
            }
        }
    end

    def test_name_equality
        #puts "Component is %s, id %s" % [@component, @component.object_id]
        assert_equal(
            @filepath,
            @configfile.name
        )

        assert_equal(
            "sleeper",
            @sleeper.name
        )
    end

    def test_object_retrieval
        [@sleeper,@configfile].each { |obj|
            assert_equal(
                obj.class[obj.name].object_id,
                obj.object_id
            )
        }
    end

    def test_transaction
        transaction = nil
        assert_nothing_raised() {
            transaction = @component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
        assert_nothing_raised() {
            @sleeper[:running] = 0
        }
        assert_nothing_raised() {
            transaction = @component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
    end

    def test_paths
        [@configfile,@sleeper,@component].each { |obj|
            assert_nothing_raised {
                assert(obj.path.is_a?(Array))
            }
        }
    end
end

# $Id$
