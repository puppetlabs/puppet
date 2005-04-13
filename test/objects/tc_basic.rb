$:.unshift '../lib' if __FILE__ == $0 # Make this library first!

require 'blink'
require 'test/unit'

# $Id$

class TestBasic < Test::Unit::TestCase
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def setup
        @component = nil
        @configfile = nil
        @sleeper = nil

        Blink[:debug] = 1

        assert_nothing_raised() {
            unless Blink::Component.has_key?("sleeper")
                Blink::Component.new(
                    :name => "sleeper"
                )
            end
            @component = Blink::Component["sleeper"]
        }

        assert_nothing_raised() {
            unless Blink::Objects::File.has_key?("../examples/root/etc/configfile")
                Blink::Objects::File.new(
                    :path => "../examples/root/etc/configfile"
                )
            end
            @configfile = Blink::Objects::File["../examples/root/etc/configfile"]
        }
        assert_nothing_raised() {
            unless Blink::Objects::Service.has_key?("sleeper")
                Blink::Objects::Service.new(
                    :name => "sleeper",
                    :running => 1
                )
                Blink::Objects::Service.addpath(
                    File.expand_path("../examples/root/etc/init.d")
                )
            end
            @sleeper = Blink::Objects::Service["sleeper"]
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
        [@component,@sleeper,@configfile].each { |obj|
            assert_nothing_raised(){
                obj.name
            }
        }
    end

    def test_name_equality
        #puts "Component is %s, id %s" % [@component, @component.object_id]
        assert_equal(
            "sleeper",
            @component.name
        )

        assert_equal(
            "../examples/root/etc/configfile",
            @configfile.name
        )

        assert_equal(
            "sleeper",
            @sleeper.name
        )
    end

    def test_object_retrieval
        [@component,@sleeper,@configfile].each { |obj|
            assert_equal(
                obj.class[obj.name].object_id,
                obj.object_id
            )
        }
    end
end
