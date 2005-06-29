if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../../../../language/trunk"
end

require 'puppet'
require 'test/unit'

# $Id$

class TestTransactions < Test::Unit::TestCase
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

        print "\n\n"
    end

    def newfile
        assert_nothing_raised() {
            cfile = File.join($puppetbase,"examples/root/etc/configfile")
            unless Puppet::Type::File.has_key?(cfile)
                Puppet::Type::File.new(
                    :path => cfile,
                    :check => [:mode, :owner, :group]
                )
            end
            return Puppet::Type::File[cfile]
        }
    end

    def newservice
        assert_nothing_raised() {
            unless Puppet::Type::Service.has_key?("sleeper")
                Puppet::Type::Service.new(
                    :name => "sleeper",
                    :check => [:running]
                )
                Puppet::Type::Service.setpath(
                    File.join($puppetbase,"examples/root/etc/init.d")
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

        component = newcomp("file",file)
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

        component = newcomp("service",service)

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

        component = newcomp("both",file,service)

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
            transaction.toplevel = true
        }

        # this should cause a restart of the service
        assert_nothing_raised() {
            transaction.evaluate
        }

        fakevent = Puppet::Event.new(
            :event => :ALL_EVENTS,
            :object => self,
            :transaction => transaction,
            :message => "yay"
        )

        sub = nil
        assert_nothing_raised() {
            sub = file.subscribers?(fakevent)
        }

        assert(sub)

        # assert we got exactly one trigger on this subscription
        # in other words, we don't want a single event to cause many
        # restarts
        # XXX i don't have a good way to retrieve this information...
        #assert_equal(1,transaction.triggercount(sub))

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

    def test_twocomps
        transaction = nil
        file = newfile()
        service = newservice()
        states = {}
        check = [:group,:mode]
        file[:check] = check

        service[:running] = 1
        service.sync

        fcomp = newcomp("file",file)
        scomp = newcomp("service",service)

        component = newcomp("both",fcomp,scomp)

        # 'requires' expects an array of arrays
        #component[:require] = [[file.class.name,file.name]]
        service[:require] = [[fcomp.class.name,fcomp.name]]

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
            transaction.toplevel = true
        }

        # this should cause a restart of the service
        assert_nothing_raised() {
            transaction.evaluate
        }

        fakevent = Puppet::Event.new(
            :event => :ALL_EVENTS,
            :object => self,
            :transaction => transaction,
            :message => "yay"
        )

        sub = nil
        assert_nothing_raised() {
            sub = fcomp.subscribers?(fakevent)
        }

        assert(sub)

        # assert we got exactly one trigger on this subscription
        # XXX this doesn't work, because the sub is being triggered in
        # a contained transaction, not this one
        #assert_equal(1,transaction.triggercount(sub))

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
