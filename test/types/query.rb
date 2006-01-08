if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet'
require 'puppettest'
require 'test/unit'

# $Id$

class TestQuery < Test::Unit::TestCase
    include TestPuppet
    # hmmm
    # this is complicated, because we store references to the created
    # objects in a central store
    def file
        assert_nothing_raised() {
            cfile = File.join($puppetbase,"examples/root/etc/configfile")
            unless Puppet.type(:file).has_key?(cfile)
                Puppet.type(:file).create(
                    :path => cfile,
                    :check => [:mode, :owner, :checksum]
                )
            end
            @configfile = Puppet.type(:file)[cfile]
        }
        return @configfile
    end

    def service
        assert_nothing_raised() {
            unless Puppet.type(:service).has_key?("sleeper")
                Puppet.type(:service).create(
                    :name => "sleeper",
                    :type => "init",
                    :path => File.join($puppetbase,"examples/root/etc/init.d"),
                    :hasstatus => true,
                    :check => [:running]
                )
            end
            @sleeper = Puppet.type(:service)["sleeper"]
        }

        return @sleeper
    end

    def component(name,*args)
        assert_nothing_raised() {
            @component = Puppet.type(:component).create(:name => name)
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
