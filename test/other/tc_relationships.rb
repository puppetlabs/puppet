if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'

# $Id$

class TestRelationships < Test::Unit::TestCase
    def setup
        Puppet[:loglevel] = :debug if __FILE__ == $0

        @groups = %x{groups}.chomp.split(/ /)
        unless @groups.length > 1
            p @groups
            raise "You must be a member of more than one group to test this"
        end
    end

    def teardown
        assert_nothing_raised() {
            Puppet::Type.allclear
        }

        print "\n\n" if Puppet[:debug]
    end

    def newfile
        assert_nothing_raised() {
            cfile = File.join($puppetbase,"examples/root/etc/configfile")
            unless Puppet::Type::PFile.has_key?(cfile)
                Puppet::Type::PFile.create(
                    :path => cfile,
                    :check => [:mode, :owner, :group]
                )
            end
            return Puppet::Type::PFile[cfile]
        }
    end

    def newservice
        assert_nothing_raised() {
            unless Puppet::Type::Service.has_key?("sleeper")
                Puppet::Type::Service.create(
                    :name => "sleeper",
                    :path => File.join($puppetbase,"examples/root/etc/init.d"),
                    :check => [:running]
                )
            end
            return Puppet::Type::Service["sleeper"]
        }
    end

    def newcomp(name,*args)
        comp = nil
        assert_nothing_raised() {
            comp = Puppet::Component.new(:name => name)
        }

        args.each { |arg|
            assert_nothing_raised() {
                comp.push arg
            }
        }

        return comp
    end

    def test_simplerel
    end
end
