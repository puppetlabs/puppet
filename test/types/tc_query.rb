if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../../../../language/trunk"
end

require 'blink'
require 'test/unit'

# $Id$

class TestQuery < Test::Unit::TestCase
    def setup
        Blink[:debug] = true
    end

    def teardown
        assert_nothing_raised() {
            Blink::Type.allclear
        }
    end

    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def file
        assert_nothing_raised() {
            cfile = File.join($blinkbase,"examples/root/etc/configfile")
            unless Blink::Type::File.has_key?(cfile)
                Blink::Type::File.new(
                    :path => cfile,
                    :check => [:mode, :owner]
                )
            end
            @configfile = Blink::Type::File[cfile]
        }
        return @configfile
    end

    def service
        assert_nothing_raised() {
            unless Blink::Type::Service.has_key?("sleeper")
                Blink::Type::Service.new(
                    :name => "sleeper",
                    :check => [:running]
                )
                Blink::Type::Service.setpath(
                    File.join($blinkbase,"examples/root/etc/init.d")
                )
            end
            @sleeper = Blink::Type::Service["sleeper"]
        }

        return @sleeper
    end

    def component(name,*args)
        assert_nothing_raised() {
            @component = Blink::Component.new(:name => name)
        }

        args.each { |arg|
            assert_nothing_raised() {
                @component.push arg
            }
        }

        return @component
    end

    def test_file
        yayfile = file()
        #p yayfile
        yayfile.eachstate { |state|
            assert_nil(state.is)
        }

        assert_nothing_raised() {
            yayfile.retrieve
        }

        assert_nothing_raised() {
            yayfile[:check] = :group
        }

        assert_nothing_raised() {
            yayfile.retrieve
        }
    end

    def test_service
        service = service()
        service.eachstate { |state|
            assert_nil(state.is)
        }

        assert_nothing_raised() {
            service.retrieve
        }
    end

    def test_component
        component = component("a",file(),service())

        assert_nothing_raised() {
            component.retrieve
        }
    end
end
