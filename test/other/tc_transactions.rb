if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $blinkbase = "../../../../language/trunk"
end

require 'blink'
require 'test/unit'

# $Id$

class TestTransactions < Test::Unit::TestCase
    def setup
        Blink[:debug] = true

        @groups = %x{groups}.chomp.split(/ /)
        unless @groups.length > 1
            p @groups
            raise "You must be a member of more than one group to test this"
        end
    end

    def teardown
        assert_nothing_raised() {
            Blink::Type.allclear
        }
    end

    def newfile
        assert_nothing_raised() {
            cfile = File.join($blinkbase,"examples/root/etc/configfile")
            unless Blink::Type::File.has_key?(cfile)
                Blink::Type::File.new(
                    :path => cfile,
                    :check => [:mode, :owner, :group]
                )
            end
            return Blink::Type::File[cfile]
        }
    end

    def newservice
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
            return Blink::Type::Service["sleeper"]
        }
    end

    def newcomp(*args)
        comp = nil
        assert_nothing_raised() {
            comp = Blink::Component.new
        }

        args.each { |arg|
            assert_nothing_raised() {
                comp.push arg
            }
        }

        return comp
    end

    def test_filetrans
        transaction = nil
        file = newfile()
        states = {}
        check = [:group,:mode]
        file[:check] = check

        assert_nothing_raised() {
            file.retrieve
        }

        check.each { |state|
            states[state] = file[state]
        }

        component = newcomp(file)
        assert_nothing_raised() {
            file[:group] = @groups[1]
            file[:mode] = "755"
        }
        assert_nothing_raised() {
            transaction = component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
        assert_nothing_raised() {
            transaction.rollback
        }
        assert_nothing_raised() {
            file.retrieve
        }
        states.each { |state,value|
            assert_equal(
                value,file[state]
            )
        }
    end

    def test_servicetrans
        transaction = nil
        service = newservice
        service[:check] = [:running]

        component = newcomp(service)

        assert_nothing_raised() {
            service.retrieve
        }
        state = service[:running]
        assert_nothing_raised() {
            service[:running] = 1
        }
        assert_nothing_raised() {
            transaction = component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
        assert_nothing_raised() {
            service[:running] = 0
        }
        assert_nothing_raised() {
            transaction = component.evaluate
        }
        assert_nothing_raised() {
            transaction.evaluate
        }
    end

    def test_both
        transaction = nil
        file = newfile()
        service = newservice()
        states = {}
        check = [:group,:mode]
        file[:check] = check

        service[:running] = 1
        service.sync

        component = newcomp(file,service)

        # 'requires' expects an array of arrays
        service[:require] = [[file.class.name,file.name]]

        assert_nothing_raised() {
            file.retrieve
            service.retrieve
        }

        check.each { |state|
            states[state] = file[state]
        }
        assert_nothing_raised() {
            file[:group] = @groups[1]
            file[:mode] = "755"
        }
        assert_nothing_raised() {
            transaction = component.evaluate
        }

        # this should cause a restart of the service
        assert_nothing_raised() {
            transaction.evaluate
        }

        # now set everything back to how it was
        assert_nothing_raised() {
            service[:running] = 0
            service.sync
            check.each { |state|
                file[state] = states[state]
            }
            file.sync
        }

    end

end
